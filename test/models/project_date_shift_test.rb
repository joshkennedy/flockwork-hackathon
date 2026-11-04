require "test_helper"

class ProjectDateShiftTest < ActiveSupport::TestCase
  test "shifts all saved dates while preserving claims assignments and undated work" do
    project = projects(:community_meal)
    start = project.starts_on
    task = project.tasks.create!(title: "Prepare", due_on: start - 1, assignee: people(:volunteer))
    undated = project.tasks.create!(title: "Someday")
    schedule = project.schedule_items.first!
    schedule_date = schedule.date
    slot = project.slots.create!(label: "Serve", date: start, capacity: 2)
    claim = slot.slot_claims.create!(person: people(:volunteer))
    list = project.lists.create!(name: "Dates")
    column = list.columns.create!(name: "Due", column_type: :date)
    row = list.rows.create!(cells: { column.id.to_s => start.iso8601 })

    ProjectDateShift.new(project, days: 7).call

    assert_equal start + 7, project.reload.starts_on
    assert_equal start + 6, task.reload.due_on
    assert_equal schedule_date + 7, schedule.reload.date
    assert_equal start + 7, slot.reload.date
    assert_equal (start + 7).iso8601, row.reload.cells[column.id.to_s]
    assert_nil undated.reload.due_on
    assert_equal people(:volunteer).id, task.assignee_id
    assert_equal slot.id, claim.reload.slot_id
    assert_equal 1, slot.claims_count
  end

  test "invalid day shifts are rejected and mid-operation failures roll back dates" do
    project = projects(:community_meal)
    [ 0, 366, -366, 1.5, "7 days", nil ].each do |days|
      assert_raises(ArgumentError) { ProjectDateShift.new(project, days:) }
    end
    original = project.starts_on
    list = project.lists.create!(name: "Dates")
    column = list.columns.create!(name: "Due", column_type: :date)
    row = list.rows.create!(cells: {})
    row.update_column(:cells, { column.id.to_s => "invalid-date" })

    assert_raises(Date::Error) { ProjectDateShift.new(project, days: 7).call }
    assert_equal original, project.reload.starts_on
  end
end
