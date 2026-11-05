module Policy
  module_function

  def visible_projects(person)
    projects = person.organization.projects.where(deleted_at: nil)
    return projects if person.admin?

    member_projects = projects.joins(:memberships).where(memberships: { person_id: person.id })
    open_team_projects = projects.where(open_team: true, archived_at: nil)
    member_projects.or(open_team_projects).distinct
  end

  def member?(person, project)
    project.memberships.exists?(person: person)
  end

  def listed_projects(person)
    visible_projects(person).where(archived_at: nil)
  end

  def archived_projects(person)
    visible_projects(person).where.not(archived_at: nil)
  end

  def deleted_projects(person)
    return person.organization.projects.none unless person.admin?

    person.organization.projects.where.not(deleted_at: nil)
  end

  def can?(person, action, record)
    if record == ::Notification
      return action.in?([ :index, :mark_all_read ])
    end

    if record.is_a?(::Notification)
      return notification_can?(person, action, record)
    end

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

    if record.is_a?(::Follow)
      return follow_can?(person, action, record)
    end

    if record.is_a?(::DocItem)
      return doc_item_access?(person, action, record)
    end

    if record.is_a?(::Task)
      return task_can?(person, action, record)
    end

    if record.is_a?(::Unavailability)
      return record.organization_id == person.organization_id && record.person_id == person.id
    end

    if record.is_a?(::CheckIn)
      # The note is Admin-only; Leaders and Admins may see that a check-in happened, by whom and when.
      return record.organization_id == person.organization_id && person.admin? if action == :view_note

      return false
    end

    if record.is_a?(::Note)
      return note_can?(person, action, record)
    end

    return can_respond_to_invitation?(person, action, record) if record.is_a?(::Invitation)
    return can_manage_membership?(person, action, record) if record.is_a?(::Membership)

    if record.is_a?(::Organization)
      return false unless record.id == person.organization_id

      return person.admin? || leader_somewhere?(person) if action == :view_oversight
      return person.admin? if action == :update_oversight
      return person.admin? if action == :manage_people
      return person.admin? if action == :manage_directory_source
      return person.admin? if action == :manage_settings

      return false
    end

    if record.is_a?(::Person)
      return false unless record.organization_id == person.organization_id

      return person.admin? || record.id == person.id if action == :view_involvement
      return person.admin? || leader_somewhere?(person) if action == :log_check_in

      return false
    end

    return false unless record.is_a?(::Project)
    return false unless record.organization_id == person.organization_id

    if action == :restore
      return person.admin? && record.deleted_at.present?
    end

    if action == :destroy
      return person.admin? && record.deleted_at.nil?
    end

    return false unless record.deleted_at.nil?

    case action
    when :show
      person.admin? || member?(person, record) || open_team_visible?(person, record)
    when :view_team, :view_recipients
      person.admin? || member?(person, record)
    when :view_notes
      person.admin? || member?(person, record)
    when :join
      open_team_visible?(person, record)
    when :update, :manage_tools, :manage_schedule, :manage_budget, :manage_tasks, :manage_team
      person.admin? || record.memberships.leader.exists?(person: person)
    when :manage_lists, :manage_slots
      person.admin? || record.memberships.leader.exists?(person: person)
    when :manage_docs, :manage_list_rows, :claim_slot
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
    when :post_message, :view_recipients
      person.admin? || record.memberships.exists?(person: person)
    when :manage_recipients
      person.admin? || record.memberships.leader.exists?(person: person)
    when :manage_public_link, :duplicate, :plan
      project_leader_or_admin?(person, record)
    when :comment
      person.admin? || record.memberships.exists?(person: person)
    else
      false
    end
  end

  def budget_line_can?(person, action, budget_line)
    project = budget_line.project
    return false unless project.organization_id == person.organization_id
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

  def task_can?(person, action, task)
    project = task.project
    return false unless project.organization_id == person.organization_id
    return false unless project.deleted_at.nil?

    team_member = project.memberships.exists?(person: person)
    responsible = task.assignee_id == person.id || project_leader_or_admin?(person, project)

    case action
    when :claim_task
      team_member && task.completed_at.nil?
    when :unclaim_task
      team_member && task.completed_at.nil? && task.assignee_id == person.id
    when :mark_task_done
      responsible && task.completed_at.nil?
    when :reopen_task
      responsible && task.completed_at.present?
    else
      false
    end
  end
  private :task_can?

  def can_respond_to_invitation?(person, action, invitation)
    action == :respond && invitation.pending? && invitation.person_id == person.id &&
      invitation.organization_id == person.organization_id
  end

  def visible_invitations(person)
    person.organization.invitations.pending.where(person: person)
  end

  def can_manage_membership?(person, action, membership)
    project = membership.project
    return false unless project.organization_id == person.organization_id && project.deleted_at.nil?
    return false if membership.person_id == project.owner_id

    case action
    when :leave_team
      membership.person_id == person.id
    when :remove_member
      person.admin? || project.memberships.leader.exists?(person: person)
    else
      false
    end
  end

  def message_can?(person, action, message)
    project = message.project
    return false unless project.organization_id == person.organization_id
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

  # A Leader of any active Project may use Oversight; the page itself reads org-wide serving counts (Oversight.serving_load), not just the Projects they lead.
  def leader_somewhere?(person)
    person.memberships.leader.joins(:project).merge(Project.active).exists?
  end
  private :leader_somewhere?

  def project_leader_or_admin?(person, record)
    person.admin? || record.memberships.leader.exists?(person: person)
  end
  private :project_leader_or_admin?

  def follow_can?(person, action, follow)
    action == :unfollow && follow.person_id == person.id && can?(person, :show, follow.followable.project)
  end
  private :follow_can?

  def open_team_visible?(person, project)
    project.organization_id == person.organization_id &&
      project.deleted_at.nil? &&
      project.archived_at.nil? &&
      project.open_team?
  end
  private :open_team_visible?

  def doc_item_access?(person, action, record)
    project = record.project
    return false unless project.organization_id == person.organization_id
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

  def visible_notes(person, scope)
    notes = scope.where(organization_id: person.organization_id)
    return notes if person.admin?

    member_project_ids = person.memberships.select(:project_id)
    leader_project_ids = person.memberships.leader.select(:project_id)
    member_recipient_ids = Recipient.where(project_id: member_project_ids).select(:id)
    leader_recipient_ids = Recipient.where(project_id: leader_project_ids).select(:id)

    team_notes = notes.team.where(notable_type: "Project", notable_id: member_project_ids)
      .or(notes.team.where(notable_type: "Recipient", notable_id: member_recipient_ids))
    leader_notes = notes.leaders.where(notable_type: "Project", notable_id: leader_project_ids)
      .or(notes.leaders.where(notable_type: "Recipient", notable_id: leader_recipient_ids))
    authored_notes = notes.where(author_id: person.id).where.not(notable_type: "Person")

    team_notes.or(leader_notes).or(authored_notes)
  end

  def writable_note_visibilities(person, notable)
    return person.admin? ? [ "admins" ] : [] if notable.is_a?(Person)

    Note.visibilities.keys.select do |visibility|
      note = Note.new(organization: person.organization, notable: notable, author: person, visibility: visibility)
      can?(person, :write_note, note)
    end
  end

  def note_can?(person, action, note)
    return false unless action == :write_note
    return false unless note.organization_id == person.organization_id
    return person.admin? if note.notable.is_a?(Person)

    project = note.project
    return false unless project&.organization_id == person.organization_id
    return false if project.deleted_at.present?
    return true if person.admin?
    return false unless project.memberships.exists?(person: person)
    return true if note.team? || note.leaders?

    note.admins? && project.memberships.leader.exists?(person: person)
  end
  private :note_can?

  def visible_notifications(person)
    notifications = person.organization.notifications.in_app.where(recipient_id: person.id)
    project_ids = visible_projects(person).select(:id)
    invitation_ids = person.organization.invitations.where.not(status: :pending).where(project_id: project_ids)
      .or(person.organization.invitations.pending.where(person_id: person.id))
      .select(:id)
    comment_ids = visible_project_comment_ids(project_ids)
    mention_ids = Mention.where(mentionable_type: "Message", mentionable_id: Message.where(project_id: project_ids).select(:id))
      .or(Mention.where(mentionable_type: "Comment", mentionable_id: comment_ids))
      .select(:id)

    notifications.where(notifiable_type: "Project", notifiable_id: project_ids)
      .or(notifications.where(notifiable_type: "Invitation", notifiable_id: invitation_ids))
      .or(notifications.where(notifiable_type: "Task", notifiable_id: Task.where(project_id: project_ids).select(:id)))
      .or(notifications.where(notifiable_type: "Slot", notifiable_id: Slot.where(project_id: project_ids).select(:id)))
      .or(notifications.where(notifiable_type: "Comment", notifiable_id: comment_ids))
      .or(notifications.where(notifiable_type: "Mention", notifiable_id: mention_ids))
  end

  def visible_project_comment_ids(project_ids)
    Comment.where(commentable_type: "BudgetLine", commentable_id: BudgetLine.where(project_id: project_ids).select(:id))
      .or(Comment.where(commentable_type: "DocItem", commentable_id: DocItem.where(project_id: project_ids).select(:id)))
      .or(Comment.where(commentable_type: "ListRow", commentable_id: ListRow.joins(:list).where(lists: { project_id: project_ids }).select(:id)))
      .or(Comment.where(commentable_type: "Message", commentable_id: Message.where(project_id: project_ids).select(:id)))
      .or(Comment.where(commentable_type: "ScheduleItem", commentable_id: ScheduleItem.where(project_id: project_ids).select(:id)))
      .or(Comment.where(commentable_type: "Slot", commentable_id: Slot.where(project_id: project_ids).select(:id)))
      .or(Comment.where(commentable_type: "Task", commentable_id: Task.where(project_id: project_ids).select(:id)))
      .select(:id)
  end
  private :visible_project_comment_ids

  def notification_can?(person, action, notification)
    action == :mark_read && notification.recipient_id == person.id &&
      notification.recipient.organization_id == person.organization_id
  end
  private :notification_can?
end
