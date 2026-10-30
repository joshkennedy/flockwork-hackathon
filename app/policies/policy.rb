module Policy
  module_function

  def visible_projects(person)
    projects = person.workspace.projects.where(deleted_at: nil)
    return projects if person.admin?

    # Ticket 05 adds Open Team Projects to this relation.
    projects.joins(:memberships).where(memberships: { person_id: person.id }).distinct
  end

  def can?(person, action, record)
    return action == :create if record == Project
    return false unless record.is_a?(Project)
    return false unless record.workspace_id == person.workspace_id && record.deleted_at.nil?

    case action
    when :show
      person.admin? || record.memberships.exists?(person: person)
    when :update, :manage_tools, :manage_schedule
      person.admin? || record.memberships.leader.exists?(person: person)
    else
      false
    end
  end
end
