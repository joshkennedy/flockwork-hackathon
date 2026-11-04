require "test_helper"

class PlannerDateShiftTest < ActiveSupport::TestCase
  test "legacy review keeps dates unchanged until accepted and never replays acceptance" do
    project = projects(:community_meal)
    original = project.starts_on
    session = project.planner_sessions.create!(started_by: people(:leader), description: "Push everything a week later", status: :reviewing,
      suggestions: [ { id: "shift-one", kind: "shift_project_dates", status: "proposed", fields: { days: 7 } } ])
    session.decide_suggestion!(id: "shift-one", decision: "keep")
    assert_equal original, project.reload.starts_on
    session.accept!(include_proposed: false)
    assert_equal original + 7, project.reload.starts_on
    session.accept!(include_proposed: true)
    assert_equal original + 7, project.reload.starts_on
  end

  test "dropping a shift leaves dates unchanged" do
    project = projects(:community_meal)
    original = project.starts_on
    session = project.planner_sessions.create!(started_by: people(:leader), description: "Push everything a week later", status: :reviewing,
      suggestions: [ { id: "shift-one", kind: "shift_project_dates", status: "proposed", fields: { days: 7 } } ])
    session.decide_suggestion!(id: "shift-one", decision: "drop")
    session.accept!(include_proposed: true)
    assert_equal original, project.reload.starts_on
  end

  test "current preview validates and creates the shift from the shared registry" do
    project = projects(:community_meal)
    original = project.starts_on
    items = Planner::PendingItems.reconcile(existing: [], added: [ { kind: "shift_project_dates", source_key: "shift-dates", fields: { days: 7 } } ], removed_ids: [], project:)
    assert_empty Planner::PendingItems.errors(items.sole, project:)
    assert_includes Planner::PendingItems.summary(items.sole), "Keep existing claims"
    Planner::PendingItems.create!(project, items.sole)
    assert_equal original + 7, project.reload.starts_on
    assert_raises(ArgumentError) do
      Planner::PendingItems.reconcile(existing: [], added: [ { kind: "shift_project_dates", source_key: "shift-dates", fields: { days: 900 } } ], removed_ids: [], project:)
    end
  end

  test "accepting a current preview shifts saved work before adding new dated work and cannot replay" do
    project = projects(:community_meal)
    original = project.starts_on
    task = project.tasks.create!(title: "Already saved", due_on: original)
    items = Planner::PendingItems.reconcile(existing: [], added: [
      { kind: "task", source_key: "new-work", fields: { title: "New dated work", details: "", due_on: original.iso8601 } },
      { kind: "shift_project_dates", source_key: "shift-dates", fields: { days: 7 } }
    ], removed_ids: [], project:)
    session = project.planner_sessions.create!(started_by: people(:leader), description: "Move saved work", status: :reviewing,
      flow_version: 3, planning_kind: "workday", pending_items: items)

    session.accept_visible!
    session.accept_visible!
    assert_equal original + 7, project.reload.starts_on
    assert_equal original + 7, task.reload.due_on
    assert_equal original, project.tasks.find_by!(title: "New dated work").due_on
    assert_equal 1, project.tasks.where(title: "New dated work").count
  end
end
