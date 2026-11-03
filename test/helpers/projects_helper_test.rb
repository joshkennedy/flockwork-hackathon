require "test_helper"

class ProjectsHelperTest < ActionView::TestCase
  setup do
    travel_to Date.new(2027, 2, 10)
    @project = projects(:community_meal)
    @project.update!(enabled_tools: %w[recipients messages signup_sheet tasks], starts_on: Date.new(2027, 2, 10), ends_on: Date.new(2027, 2, 20))
    @project.tasks.delete_all
  end

  test "tabs put the working Tool first and leave Recipients to the side column" do
    assert_equal %w[signup_sheet tasks messages], project_tabs(@project)

    @project.tasks.create!(title: "Set up chairs")
    assert_equal %w[tasks signup_sheet messages], project_tabs(@project)
  end

  test "date ranges drop the current year" do
    assert_equal "Feb 10 – Feb 20", project_date_range(Date.new(2027, 2, 10), Date.new(2027, 2, 20))
    assert_equal "Feb 10", project_date_range(Date.new(2027, 2, 10), Date.new(2027, 2, 10))
    assert_equal "Jan 2, 2028", project_date_range(Date.new(2028, 1, 2), nil)
  end

  test "due labels are relative near today and fall back to the calendar date" do
    today = Date.new(2027, 2, 10)

    assert_equal "Overdue by 2 days", task_due_label(Date.new(2027, 2, 8), today: today)
    assert_equal "Due today", task_due_label(today, today: today)
    assert_equal "Due tomorrow", task_due_label(Date.new(2027, 2, 11), today: today)
    assert_equal "Due in 13 days", task_due_label(Date.new(2027, 2, 23), today: today)
    assert_equal "Due in 2 weeks", task_due_label(Date.new(2027, 2, 24), today: today)
    assert_equal "Due Apr 9", task_due_label(Date.new(2027, 4, 9), today: today)
    assert_equal "Due Jan 4, 2028", task_due_label(Date.new(2028, 1, 4), today: today)
  end

  test "status counts covered Slots by their shared label and names the next open one" do
    @project.slots.create!(date: Date.new(2027, 2, 9), label: "Dinner", capacity: 1).claim(people(:volunteer))
    @project.slots.create!(date: Date.new(2027, 2, 12), label: "Dinner", capacity: 1)

    assert_equal [ [ "When", "Feb 10 – Feb 20" ], [ "Covered", "1 of 2 dinners" ], [ "Next open", "Fri, Feb 12" ] ],
      project_status_items(@project)
  end

  test "guidance counts open future spots and offers the next Slot this person hasn't claimed" do
    @project.slots.create!(date: Date.new(2027, 2, 9), label: "Dinner", capacity: 1)
    mine = @project.slots.create!(date: Date.new(2027, 2, 11), label: "Dinner", capacity: 2)
    mine.claim(people(:volunteer))
    nextup = @project.slots.create!(date: Date.new(2027, 2, 12), label: "Dinner", capacity: 1)

    guidance = project_guidance(@project, people(:volunteer))

    assert_equal "2 spots still open", guidance[:title]
    assert_equal nextup, guidance[:slot]
  end

  test "guidance falls back to unassigned Tasks, then to nothing" do
    @project.tasks.create!(title: "Set up chairs")
    assert_equal "1 task has no one on it", project_guidance(@project, people(:leader))[:title]

    @project.tasks.update_all(completed_at: Time.current)
    assert_nil project_guidance(@project, people(:leader))
  end

  test "Slots for several people are counted in spots" do
    slot = @project.slots.create!(date: Date.new(2027, 2, 12), label: "Check-in helper", capacity: 3)
    slot.claim(people(:volunteer))

    assert_includes project_status_items(@project), [ "Covered", "1 of 3 spots" ]
    assert_equal "2 spots still open", project_guidance(@project, people(:leader))[:title]
  end

  test "a done Project needs nothing" do
    @project.slots.create!(date: Date.new(2027, 2, 12), label: "Dinner", capacity: 1)
    @project.update!(done_at: Time.current)
    assert_nil project_guidance(@project, people(:leader))
  end
end
