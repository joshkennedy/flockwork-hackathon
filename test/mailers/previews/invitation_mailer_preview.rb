# Preview at /rails/mailers/invitation_mailer
class InvitationMailerPreview < ActionMailer::Preview
  # Built in memory, so opening a preview never writes to the database.
  def invitation
    project = Project.where.not(description: [ nil, "" ]).first || Project.first!
    invitation = Invitation.new(
      id: 0,
      organization: project.organization,
      project: project,
      person: project.organization.people.where.not(email: nil).last!,
      inviter: project.owner,
      role: "volunteer"
    )
    InvitationMailer.invitation(invitation)
  end
end
