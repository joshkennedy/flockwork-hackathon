require "test_helper"

class ProjectRecurrenceJobTest < ActiveSupport::TestCase
  test "daily generation creates only upcoming copies and copies do not repeat themselves" do
    travel_to Date.new(2027, 2, 1) do
      project = projects(:community_meal)
      project.update!(starts_on: Date.new(2020, 2, 3), ends_on: Date.new(2020, 2, 3))
      recurrence = project.create_project_recurrence!(creator: people(:leader), frequency: :weekly, anchor_on: project.starts_on, enabled: true)

      assert_difference "Project.count", 2 do
        ProjectRecurrenceJob.perform_now
        ProjectRecurrenceJob.perform_now
      end
      assert_equal [ Date.new(2027, 2, 1), Date.new(2027, 2, 8) ], recurrence.project_occurrences.order(:on).pluck(:on)
      assert_equal 1, ProjectRecurrence.count
    end
  end
end
