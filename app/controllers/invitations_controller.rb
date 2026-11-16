class InvitationsController < ApplicationController
  allow_unauthenticated_access only: :show
  before_action :set_show_invitation, only: :show
  rate_limit to: 5, within: 10.minutes, by: -> { Current.session.id }, name: "demo_session",
    scope: "demo_outbound_actions", only: :create, if: :demo_organization?
  rate_limit to: 20, within: 10.minutes, by: -> { request.remote_ip }, name: "demo_ip",
    scope: "demo_outbound_actions", only: :create, if: :demo_organization?
  before_action :set_response_invitation, only: %i[ accept decline ]

  def show
    resume_session
    unless Current.person == @invitation.person
      if invitation_sign_in_allowed? && DemoOutboundLimit.allow_for_person?(@invitation.person)
        SignInMailer.sign_in_link(@invitation.person).deliver_later
      end
      return render :confirm
    end

    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :respond, @invitation)
  end

  def create
    project = Policy.visible_projects(Current.person).find(params[:project_id])
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_team, project)
    raise ActiveRecord::RecordNotFound if project.archived_at?

    person, invitation = create_invitation!(project)
    Notifier.notify(
      recipient: person,
      kind: "invitation",
      notifiable: invitation,
      actor: Current.person
    )
    redirect_to team_project_path(project), notice: "Invited #{person.name}."
  rescue ActiveRecord::RecordInvalid => error
    query = Current.organization.people.find_by(id: invitation_params[:person_id])&.name
    redirect_to team_project_path(project, query: query), alert: error.record.errors.full_messages.to_sentence
  end

  def accept
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :accept, @invitation)

    @invitation.accept!
    redirect_to team_project_path(@invitation.project), notice: "You joined the Team."
  end

  def decline
    @invitation.decline!
    redirect_to home_path, notice: "You declined the Invitation."
  end

  private
    SIGN_IN_SEND_LIMIT = 3
    SIGN_IN_SEND_WINDOW = 15.minutes

    def invitation_sign_in_allowed?
      count = self.class.cache_store.increment(
        "invitation-sign-in:v1:#{params[:token]}",
        1,
        expires_in: SIGN_IN_SEND_WINDOW
      )
      count.nil? || count <= SIGN_IN_SEND_LIMIT
    end

    def set_show_invitation
      @invitation = Invitation.find_by_token_for(:access, params[:token])
      render :invalid, status: :unprocessable_content unless @invitation&.pending?
    end

    def set_response_invitation
      @invitation = Current.organization.invitations.find_by_token_for(:access, params[:token])
      raise ActiveRecord::RecordNotFound unless @invitation
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :respond, @invitation)
    end

    def create_invitation!(project)
      Invitation.transaction do
        person = if invitation_params[:person_id].present?
          Current.organization.people.find(invitation_params[:person_id])
        else
          create_invitee!
        end
        invitation = Current.organization.invitations.create!(
          project: project,
          person: person,
          inviter: Current.person,
          role: invitation_params[:role]
        )
        [ person, invitation ]
      end
    end

    def create_invitee!
      email = Person.normalize_value_for(:email, invitation_params[:email].to_s)
      person = Current.organization.people.find_or_initialize_by(email: email)
      person.assign_attributes(name: invitation_params[:name], added_by: Current.person) if person.new_record?
      person.save!
      person
    end

    def invitation_params
      params.expect(invitation: [ :person_id, :name, :email, :role ])
    end
end
