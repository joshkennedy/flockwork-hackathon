class Membership < ApplicationRecord
  belongs_to :project
  belongs_to :person

  enum :role, { leader: 0, volunteer: 1 }

  validates :person_id, uniqueness: { scope: :project_id }

  after_destroy :unassign_tasks
  after_destroy { person.slot_claims.joins(:slot).where(slots: { project_id: project_id }).destroy_all }
  after_destroy :notify_leaders_of_departure

  private
    def unassign_tasks
      project.tasks.where(assignee_id: person_id).update_all(assignee_id: nil)
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
