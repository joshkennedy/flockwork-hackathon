# Signs a helper in from a Project's Public link with a code sent by email or text. Someone the church does not
# know yet is asked for a name only after the code is verified, so no step reveals who is already a Person.
class GuestSignInsController < ApplicationController
  layout "public"

  allow_unauthenticated_access
  before_action :set_project, except: %i[ link open_link ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { too_many_requests }
  rate_limit to: 20, within: 3.minutes, only: %i[ verify open_link ], name: "verify", with: -> { too_many_requests }
  before_action :set_challenge, only: %i[ code verify ]
  before_action :set_verified_challenge, only: %i[ name finish ]

  def new
    if authenticated? && Current.person.organization_id == @project.organization_id
      redirect_to public_project_path(@project.public_token)
    else
      session[:guest_slot_id] = params[:slot_id].presence
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

    challenge = SignInChallenge.issue(organization: @project.organization, project: @project, channel:, address:)
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
      @error = "That code isn’t right. Check it and try again."
      render :code, status: :unprocessable_content
    else
      ask_again("That code has expired or was tried too many times. Send a new one.")
    end
  end

  def name
  end

  def finish
    @person = @challenge.person || @challenge.build_person(name: params[:name].to_s.squish)
    if @person.save
      sign_in(@person, @challenge, session[:guest_auth_method] || "#{@challenge.channel}_code")
    else
      render :name, status: :unprocessable_content
    end
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
      challenge if @project
    end

    def sign_in_or_ask_name(challenge, auth_method)
      if (person = challenge.person)
        sign_in(person, challenge, auth_method)
      else
        session[:guest_verified_challenge_id] = challenge.id
        session[:guest_auth_method] = auth_method
        redirect_to guest_sign_in_name_path(challenge.project.public_token), status: :see_other
      end
    end

    # The challenge is deleted once it has signed someone in, so neither the code nor the name step can be replayed.
    # Checked again here because the phone's Person can change between sending the code and using it.
    def sign_in(person, challenge, auth_method)
      slot = challenge.project.slots.find_by(id: session[:guest_slot_id])
      %i[ guest_challenge_id guest_verified_challenge_id guest_auth_method guest_slot_id ].each { |key| session.delete(key) }
      challenge.destroy!
      return ask_again("Use your email to sign in.") if challenge.texts_an_admin?(person)
      start_new_session_for person, auth_method:, verified_email: (challenge.address if challenge.channel == "email")
      redirect_to public_project_path(challenge.project.public_token, anchor: (helpers.dom_id(slot) if slot)), status: :see_other
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
