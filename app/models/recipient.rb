class Recipient < ApplicationRecord
  belongs_to :project
  belongs_to :person

  validates :person_id, uniqueness: { scope: :project_id }
  validate :person_is_not_on_team

  private
    def person_is_not_on_team
      return unless project && person_id

      return unless project.memberships.exists?(person_id: person_id)

      errors.add(:person, "is already on the Team")
    end
end
