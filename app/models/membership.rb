class Membership < ApplicationRecord
  belongs_to :project
  belongs_to :person

  enum :role, { leader: 0, volunteer: 1 }

  validates :person_id, uniqueness: { scope: :project_id }
end
