module Policy
  module_function

  def visible_projects(person)
    projects = person.workspace.projects.where(deleted_at: nil)
    return projects if person.admin?

    # Ticket 05 adds Open Team Projects to this relation.
    projects.joins(:memberships).where(memberships: { person_id: person.id }).distinct
  end

  def listed_projects(person)
    visible_projects(person).where(archived_at: nil)
  end

  def archived_projects(person)
    visible_projects(person).where.not(archived_at: nil)
  end

  def deleted_projects(person)
    return person.workspace.projects.none unless person.admin?

    person.workspace.projects.where.not(deleted_at: nil)
  end

  def can?(person, action, record)
    if record == ::Project
      return true if action == :create
      return person.admin? if action == :view_deleted

      return false
    end

    if record.is_a?(::BudgetLine)
      return budget_line_can?(person, action, record)
    end

    if record.is_a?(::Message)
      return message_can?(person, action, record)
    end

    if record.is_a?(::DocItem)
      return doc_item_access?(person, action, record)
    end

    return false unless record.is_a?(::Project)
    return false unless record.workspace_id == person.workspace_id

    if action == :restore
      return person.admin? && record.deleted_at.present?
    end

    if action == :destroy
      return person.admin? && record.deleted_at.nil?
    end

    return false unless record.deleted_at.nil?

    case action
    when :show
      person.admin? || record.memberships.exists?(person: person)
    when :update, :manage_tools, :manage_schedule, :manage_budget
      person.admin? || record.memberships.leader.exists?(person: person)
    when :manage_docs
      person.admin? || record.memberships.exists?(person: person)
    when :mark_done
      project_leader_or_admin?(person, record) && record.done_at.nil?
    when :reopen
      project_leader_or_admin?(person, record) && record.done_at.present?
    when :archive
      record.owner_id == person.id && record.archived_at.nil?
    when :unarchive
      record.owner_id == person.id && record.archived_at.present?
    when :transfer_ownership
      record.owner_id == person.id
    when :post_message
      person.admin? || record.memberships.exists?(person: person)
    else
      false
    end
  end

  def budget_line_can?(person, action, budget_line)
    project = budget_line.project
    return false unless project.workspace_id == person.workspace_id
    return false unless project.deleted_at.nil?

    case action
    when :manage_budget
      project_leader_or_admin?(person, project)
    when :update_budget_line_status
      budget_line.responsible_person_id == person.id &&
        (person.admin? || project.memberships.exists?(person: person))
    else
      false
    end
  end

  def message_can?(person, action, message)
    project = message.project
    return false unless project.workspace_id == person.workspace_id
    return false unless project.deleted_at.nil?
    return false unless person.admin? || project.memberships.exists?(person: person)

    case action
    when :edit_message
      message.author_id == person.id
    when :delete_message
      message.author_id == person.id || project_leader_or_admin?(person, project)
    else
      false
    end
  end
  private :message_can?

  def project_leader_or_admin?(person, record)
    person.admin? || record.memberships.leader.exists?(person: person)
  end
  private :project_leader_or_admin?

  def doc_item_access?(person, action, record)
    project = record.project
    return false unless project.workspace_id == person.workspace_id
    return false unless project.deleted_at.nil?

    case action
    when :download
      person.admin? || project.memberships.exists?(person: person)
    when :destroy
      person.admin? || record.author_id == person.id || project.memberships.leader.exists?(person: person)
    else
      false
    end
  end
  private :doc_item_access?
end
