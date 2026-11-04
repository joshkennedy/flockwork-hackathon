class ProjectDebrief < ApplicationRecord
  belongs_to :project

  normalizes :what_worked, :change_next_time, with: ->(value) { value.to_s.strip }, apply_to_nil: true

  validates :project_id, uniqueness: true
  validates :what_worked, :change_next_time, length: { maximum: 2_000 }
  validate :project_is_finished

  def notes_body
    [ [ "What worked", what_worked ], [ "What to change next time", change_next_time ] ].filter_map do |question, answer|
      "#{question}\n#{answer}" if answer.present?
    end.join("\n\n")
  end

  private
    def project_is_finished
      errors.add(:project, "must be marked done first") unless project&.done_at?
    end
end
