class InvitationMailer < ApplicationMailer
  helper ProjectsHelper

  def invitation(invitation)
    @invitation = invitation
    return if invitation.project.archived_at?
    return unless invitation.person.email.present? && invitation.person.email_for?("invitation")

    @url = invitation_url(invitation.generate_token_for(:access))

    mail to: invitation.person.email,
      subject: "You're invited to help with #{invitation.project.name} on Flockwork"
  end
end
