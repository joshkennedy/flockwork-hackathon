class ProjectDigestMailer < ApplicationMailer
  def self.eligible?(project, person)
    project.active? && !project.organization.demo? && person.email.present? &&
      person.organization_id == project.organization_id &&
      project.memberships.leader.exists?(person: person) &&
      (!person.email_preferences.key?("weekly_project_digest") ||
        ActiveModel::Type::Boolean.new.cast(person.email_preferences["weekly_project_digest"]))
  end

  def weekly(project, person)
    return unless self.class.eligible?(project, person)

    @project = project
    @person = person
    @risk = ProjectRisk.new(project)
    @url = project_url(project)
    mail to: person.email, subject: "Weekly update for #{project.name}"
  end
end
