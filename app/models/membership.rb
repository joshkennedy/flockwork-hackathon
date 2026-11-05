class Membership < ApplicationRecord
  include RefreshesDashboard
  PROJECT_FOLLOWABLES = {
    "BudgetLine" => :budget_lines,
    "DocItem" => :doc_items,
    "ListRow" => :list_rows,
    "Message" => :messages,
    "ScheduleItem" => :schedule_items,
    "Slot" => :slots,
    "Task" => :tasks
  }.freeze

  belongs_to :project
  belongs_to :person
  broadcasts_refreshes_to :project

  enum :role, { leader: 0, volunteer: 1 }

  validates :person_id, uniqueness: { scope: :project_id }

  after_destroy :unassign_tasks
  after_destroy { person.slot_claims.joins(:slot).where(slots: { project_id: project_id }).destroy_all }
  after_destroy :revoke_project_notifications_and_follows
  after_destroy :notify_leaders_of_departure
  # Open sockets keep their old stream subscriptions; reconnecting resubscribes through Policy.
  after_destroy_commit { person.sessions.each(&:disconnect_cable) }

  private
    def unassign_tasks
      project.tasks.where(assignee_id: person_id).update_all(assignee_id: nil)
    end

    def revoke_project_notifications_and_follows
      PROJECT_FOLLOWABLES.each do |type, association|
        person.follows.where(
          followable_type: type,
          followable_id: project.public_send(association).select(:id)
        ).delete_all
      end

      person.notifications.includes(:notifiable).find_each do |notification|
        notification.destroy! if notification.project == project
      end
    end

    def notify_leaders_of_departure
      project.memberships.leader.includes(:person).find_each do |membership|
        Notifier.notify(
          recipient: membership.person,
          kind: "team_departure",
          notifiable: project,
          actor: Current.person
        )
      end
    end
end
