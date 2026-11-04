require "test_helper"

class ProjectRecurrenceTest < ActiveSupport::TestCase
  setup do
    @project = projects(:community_meal)
    @project.update!(starts_on: Date.new(2027, 1, 31), ends_on: Date.new(2027, 1, 31))
    @recurrence = @project.create_project_recurrence!(creator: people(:leader), frequency: :monthly, enabled: true, anchor_on: @project.starts_on)
  end

  test "monthly dates retain the original day after a short month" do
    assert_equal [ Date.new(2027, 2, 28) ], @recurrence.upcoming_dates(Date.new(2027, 2, 22))
    assert_equal [ Date.new(2027, 3, 31) ], @recurrence.upcoming_dates(Date.new(2027, 3, 25))
  end

  test "weekly dates stay anchored without catching up old occurrences" do
    @recurrence.update!(frequency: :weekly, anchor_on: Date.new(2020, 1, 5))
    dates = @recurrence.upcoming_dates(Date.new(2027, 1, 31))
    assert_equal [ Date.new(2027, 1, 31), Date.new(2027, 2, 7) ], dates
  end

  test "generation copies structure and date offsets once per occurrence" do
    @project.update!(skills_needed: [ "Cooking" ])
    @project.tasks.create!(title: "Prepare", due_on: Date.new(2027, 1, 30), assignee: people(:volunteer))
    @project.slots.create!(label: "Serve", date: Date.new(2027, 1, 31), capacity: 3)
    list = @project.lists.create!(name: "Supplies")
    column = list.columns.create!(name: "Item", column_type: :text)
    list.rows.create!(cells: { column.id.to_s => "Plates" })

    assert_difference "Project.count", 1 do
      2.times { @recurrence.generate_upcoming(today: Date.new(2027, 2, 22)) }
    end
    occurrence = @recurrence.project_occurrences.sole
    copy = occurrence.project
    assert_equal Date.new(2027, 2, 28), occurrence.on
    assert_equal occurrence.on, copy.starts_on
    assert_equal @project.name, copy.name
    assert_equal @project.skills_needed, copy.skills_needed
    assert_equal Date.new(2027, 2, 27), copy.tasks.sole.due_on
    assert_nil copy.tasks.sole.assignee_id
    assert_equal [ [ "Serve", occurrence.on, 3 ] ], copy.slots.pluck(:label, :date, :capacity)
    assert_equal "Plates", copy.lists.find_by!(name: "Supplies").rows.sole.cells.values.sole
    assert_equal [ people(:leader).id ], copy.memberships.pluck(:person_id)
  end

  test "disabled inactive and former-Leader rules create nothing" do
    @recurrence.update!(enabled: false)
    assert_no_difference("Project.count") { @recurrence.generate_upcoming(today: Date.new(2027, 2, 22)) }
    @recurrence.update!(enabled: true)
    @project.update!(done_at: Time.current)
    assert_no_difference("Project.count") { @recurrence.generate_upcoming(today: Date.new(2027, 2, 22)) }
    @project.update!(done_at: nil)
    @project.memberships.find_by!(person: people(:leader)).destroy!
    assert_no_difference("Project.count") { @recurrence.generate_upcoming(today: Date.new(2027, 2, 22)) }
  end

  test "deleting a generated Project keeps its occurrence history" do
    @recurrence.generate_upcoming(today: Date.new(2027, 2, 22))
    occurrence = @recurrence.project_occurrences.sole
    occurrence.project.destroy!

    assert_nil occurrence.reload.project_id
    assert_no_difference "Project.count" do
      @recurrence.generate_upcoming(today: Date.new(2027, 2, 22))
    end
  end

  test "the database rejects duplicate occurrence dates" do
    @recurrence.generate_upcoming(today: Date.new(2027, 2, 22))
    occurrence = @recurrence.project_occurrences.sole
    other = Project.create_for(creator: people(:leader), attributes: { name: "Extra" })
    assert_raises ActiveRecord::RecordNotUnique do
      ProjectOccurrence.insert_all!([ { project_recurrence_id: @recurrence.id, project_id: other.id, on: occurrence.on, created_at: Time.current, updated_at: Time.current } ])
    end
  end
end
