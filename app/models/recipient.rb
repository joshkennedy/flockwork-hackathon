class Recipient < ApplicationRecord
  belongs_to :project
  belongs_to :person
  broadcasts_refreshes_to :project
  has_many :notes, as: :notable, dependent: :destroy

  validates :person_id, uniqueness: { scope: :project_id }
  validate :person_is_not_on_team

  private
    def person_is_not_on_team
      return unless project && person_id

      return unless project.memberships.exists?(person_id: person_id)

      errors.add(:person, "is already on the Team, so they can’t also be a Recipient")
    end
end
