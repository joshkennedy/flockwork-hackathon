class ProjectOccurrence < ApplicationRecord
  belongs_to :project_recurrence
  belongs_to :project, optional: true

  validates :on, presence: true, uniqueness: { scope: :project_recurrence_id }
  validates :project_id, uniqueness: true, allow_nil: true
end
