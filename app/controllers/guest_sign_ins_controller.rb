# Signs a helper in from a Project's Public link with a code sent by email or text. Someone the church does not
# know yet is asked for a name only after the code is verified, so no step reveals who is already a Person.
class GuestSignInsController < ApplicationController
  layout "public"

  allow_unauthenticated_access
  before_action :set_project, except: %i[ link open_link ]
  before_action :set_slot, only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { too_many_requests }
  rate_limit to: 20, within: 3.minutes, only: %i[ verify open_link ], name: "verify", with: -> { too_many_requests }
  before_action :set_challenge, only: %i[ code verify ]
  before_action :set_verified_challenge, only: %i[ name finish ]

  def new
    if authenticated? && Current.person.organization_id == @project.organization_id
      redirect_to public_project_path(@project.public_token, anchor: (helpers.dom_id(@slot) if @slot)),
        notice: "You’re already signed in."
    end
  end

  def create
    channel, address = SignInChallenge.parse(params[:contact])
    return ask_again("Enter an email, or a mobile number with its area code.") unless channel
    if channel == "sms"
      return ask_again("This number opted out of Flockwork texts. Use your email, or reply START to an earlier text.") if SmsOptOut.blocked?(address)
      return ask_again("Use your email for now.") unless SignInChallenge.textable?(@project.organization, address)
    end
    return ask_again("Use your email to sign in.") if SignInChallenge.new(organization: @project.organization, channel:, address:).texts_an_admin?

    challenge = SignInChallenge.issue(organization: @project.organization, project: @project, slot: @slot, channel:, address:)
    return ask_again("Too many codes sent. Wait an hour, then try again.", :too_many_requests) unless challenge

    SignInChallengeJob.perform_later(challenge) if DemoOutboundLimit.allow?(@project.organization)
    session[:guest_challenge_id] = challenge.id
    redirect_to guest_sign_in_code_path(@project.public_token), status: :see_other, notice: ("New code sent." if params[:resend])
  rescue ActiveJob::EnqueueError
    ask_again("Unable to send your code. Try again.", :service_unavailable)
  end

  def code
    redirect_to guest_sign_in_name_path(@project.public_token) if @challenge.verified?
  end

  def verify
    if @challenge.verify(params[:code].to_s.gsub(/\D/, ""))
      sign_in_or_ask_name(@challenge, "#{@challenge.channel}_code")
    elsif @challenge.open?
      @error = "That code didn’t match. Try again."
      render :code, status: :unprocessable_content
    else
      ask_again("That code has expired or was tried too many times. Send a new one.")
    end
  end

  def name
  end

  def finish
    @person = @challenge.finish(name: params[:name].to_s.squish)
    if @person.nil?
      redirect_to guest_sign_in_path(@project.public_token)
    elsif @person.persisted?
      sign_in(@person, @challenge, session[:guest_auth_method] || "#{@challenge.channel}_code")
    else
      render :name, status: :unprocessable_content
    end
  end

  # Sign out on the Public page and stay there, rather than land on the marketing home.
  def destroy
    terminate_session if authenticated?
    redirect_to public_project_path(@project.public_token), status: :see_other
  end

  # Show a confirmation button instead of consuming on GET, so link scanners that prefetch messages cannot use up the link.
  def link
    render :invalid_link, status: :unprocessable_content unless linked_challenge
  end

  def open_link
    challenge = linked_challenge
    if challenge&.consume
      sign_in_or_ask_name(challenge, "link")
    else
      render :invalid_link, status: :unprocessable_content
    end
  end

  private
    def set_project
      @project = Project.publicly_linked.find_by!(public_token: params[:token])
      @organization = @project.organization
    end

    # The slot_id comes from the page's link, so it only counts when it is one of this Project's Slots.
    def set_slot
      return unless @project.enabled_tools.include?("signup_sheet")

      @slot = @project.slots.find_by(id: params[:slot_id])
    end

    def set_challenge
      @challenge = SignInChallenge.find_by(id: session[:guest_challenge_id], project: @project)
      redirect_to guest_sign_in_path(@project.public_token) unless @challenge
    end

    # Kept apart from the challenge a browser merely asked for: only the browser that typed the code or opened
    # the link may name the new Person, never the one that requested a code for someone else's address.
    def set_verified_challenge
      @challenge = SignInChallenge.find_by(id: session[:guest_verified_challenge_id], project: @project)
      redirect_to guest_sign_in_path(@project.public_token) unless @challenge&.verified?
    end

    # A link whose Project has since turned its Public link off has nowhere to land, so it is not valid.
    def linked_challenge
      challenge = SignInChallenge.find_by_link_token(params[:link_token])
      @project = Project.publicly_linked.find_by(id: challenge&.project_id)
      @organization = @project&.organization
      challenge if @project
    end

    def sign_in_or_ask_name(challenge, auth_method)
      if (person = challenge.person)
        challenge.mark_signed_in
        sign_in(person, challenge, auth_method)
      else
        session[:guest_verified_challenge_id] = challenge.id
        session[:guest_auth_method] = auth_method
        redirect_to guest_sign_in_name_path(challenge.project.public_token), status: :see_other
      end
    end

    # Callers mark the challenge signed in first, so neither the code nor the name step can be replayed.
    # Checked again here because the phone's Person can change between sending the code and using it.
    def sign_in(person, challenge, auth_method)
      project = challenge.project
      slot = @slot = project.slots.find_by(id: challenge.slot_id) if project.enabled_tools.include?("signup_sheet")
      %i[ guest_challenge_id guest_verified_challenge_id guest_auth_method ].each { |key| session.delete(key) }
      return ask_again("Use your email to sign in.") if challenge.texts_an_admin?(person)
      start_new_session_for person, auth_method:, verified_email: (challenge.address if challenge.channel == "email")
      flash_message = claim_tapped_slot(slot, person) if slot && Policy.can?(person, :claim_public_slot, project)
      redirect_to public_project_path(project.public_token, anchor: (helpers.dom_id(slot) if slot)), status: :see_other, flash: flash_message
    end

    # Takes the Slot the helper tapped before signing in, by the same rules as claiming on the public page.
    # The claimed row the page lands on is the confirmation, so only a lost spot needs a notice.
    def claim_tapped_slot(slot, person)
      return if slot.claim_prompt.present?

      unless slot.slot_claims.exists?(person:) || slot.claim(person)&.persisted?
        { notice: "That spot filled up while you were signing in. Pick another one below." }
      end
    end

    def ask_again(message, status = :unprocessable_content)
      @error = message
      render :new, status:
    end

    def too_many_requests
      return head :too_many_requests unless @project

      ask_again("Too many tries. Wait three minutes, then try again.", :too_many_requests)
    end
end
