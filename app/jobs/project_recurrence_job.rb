class ProjectRecurrenceJob < ApplicationJob
  def perform
    ProjectRecurrence.where(enabled: true).find_each(&:generate_upcoming)
  end
end
