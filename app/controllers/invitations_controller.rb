class InvitationsController < ApplicationController
  allow_unauthenticated_access only: :show
  before_action :set_show_invitation, only: :show
  rate_limit to: 3, within: 15.minutes, by: -> { params[:token] }, name: "invitation_sign_in",
    only: :show, with: -> { render :confirm }
  before_action :set_response_invitation, only: %i[ accept decline ]

  def show
    resume_session
    unless Current.person == @invitation.person
      SignInMailer.sign_in_link(@invitation.person).deliver_later
      return render :confirm
    end

    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :respond, @invitation)
  end

  def create
    project = Policy.visible_projects(Current.person).find(params[:project_id])
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_team, project)

    person = Current.organization.people.find(invitation_params[:person_id])
    invitation = Current.organization.invitations.build(
      project: project,
      person: person,
      inviter: Current.person,
      role: invitation_params[:role]
    )

    if invitation.save
      Notifier.notify(
        recipient: person,
        kind: "invitation",
        notifiable: invitation,
        actor: Current.person
      )
      redirect_to team_project_path(project), notice: "Invited #{person.name}."
    else
      redirect_to team_project_path(project, query: person.name), alert: invitation.errors.full_messages.to_sentence
    end
  end

  def accept
    @invitation.accept!
    redirect_to team_project_path(@invitation.project), notice: "You joined the Team."
  end

  def decline
    @invitation.decline!
    redirect_to home_path, notice: "You declined the Invitation."
  end

  private
    def set_show_invitation
      @invitation = Invitation.find_by_token_for(:access, params[:token])
      render :invalid, status: :unprocessable_content unless @invitation&.pending?
    end

    def set_response_invitation
      @invitation = Current.organization.invitations.find_by_token_for(:access, params[:token])
      raise ActiveRecord::RecordNotFound unless @invitation
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :respond, @invitation)
    end

    def invitation_params
      params.expect(invitation: [ :person_id, :role ])
    end
end
