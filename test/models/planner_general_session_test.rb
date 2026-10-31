require "test_helper"

class PlannerGeneralSessionTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @leader = people(:leader)
    Current.session = @leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    @session = projects(:community_meal).planner_sessions.create!(
      started_by: @leader, description: "Plan a workday", flow_version: 3, planning_kind: "workday"
    )
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "v3 reconciles and atomically accepts all supported item kinds" do
    items = [
      item("task", "cleanup-task", "title" => "Clean the hall", "details" => "Bring gloves", "due_on" => "2027-02-13"),
      item("schedule_item", "lunch-time", "title" => "Lunch", "date" => "2027-02-14", "starts_at" => "12:00", "ends_at" => "13:00", "location" => "Hall"),
      item("booking", "dumpster", "description" => "Dumpster", "estimated_dollars" => "125.00"),
      item("purchase", "bags", "description" => "Trash bags", "estimated_dollars" => "20"),
      item("list", "supplies", "name" => "Supplies", "columns" => [ { "name" => "Item", "type" => "text" } ]),
      item("enable_tool", "messages", "tool" => "messages")
    ]
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(card: nil, finished: true, added: items, removed_ids: [])
    ])

    revision = @session.queue_generation!
    assert @session.generate!(revision:), @session.reload.last_error
    assert_predicate @session.reload, :reviewing?
    assert_equal "tasks", @session.acceptance_tool
    assert_empty @session.pending_item_errors

    assert_difference({ "Task.count" => 1, "ScheduleItem.count" => 1, "BudgetLine.count" => 2, "List.count" => 1 }) do
      receipt = @session.accept_visible!(expected_revision: revision)
      assert_equal "tasks", receipt.fetch("acceptance_tool")
    end
    assert_no_difference [ "Task.count", "ScheduleItem.count", "BudgetLine.count", "List.count" ] do
      @session.accept_visible!
    end
  end

  test "unknown budget remains editable but blocks acceptance" do
    pending = Planner::PendingItems.expand([
      item("purchase", "paint", "description" => "Paint", "estimated_dollars" => nil)
    ], project: @session.project).map(&:to_h)
    @session.update!(status: :reviewing, pending_items: pending)

    assert_equal [ "Estimated cost is required" ], @session.pending_item_errors.fetch(pending.first.fetch("id"))
    assert_raises(ArgumentError) { @session.accept_visible! }
  end

  test "source keys cannot rekey an edited item or change its kind" do
    existing = Planner::PendingItems.expand([ item("task", "stable", "title" => "Clean", "details" => "", "due_on" => nil) ], project: @session.project).map(&:to_h)
    existing.first["user_edits"] = { "title" => "Deep clean" }
    existing.first["fields"]["title"] = "Deep clean"

    assert_raises(ArgumentError) do
      Planner::PendingItems.reconcile(existing:, added: [ item("task", "replacement", "title" => "Clean", "details" => "", "due_on" => nil) ], removed_ids: [], project: @session.project)
    end
    assert_raises(ArgumentError) do
      Planner::PendingItems.reconcile(existing:, added: [ item("purchase", "stable", "description" => "Soap", "estimated_dollars" => nil) ], removed_ids: [], project: @session.project)
    end
  end

  test "setting the first Project start date preserves explicit dates and an explicitly cleared due date" do
    @session.project.update!(starts_on: nil, ends_on: nil)
    pending = Planner::PendingItems.expand([
      item("task", "task", "title" => "Confirm crew", "details" => "", "due_on" => "2027-04-11"),
      item("schedule_item", "briefing", "title" => "Briefing", "date" => "2027-04-10", "starts_at" => "09:00", "ends_at" => "09:30", "location" => "Hall")
    ], project: @session.project).map(&:to_h)
    @session.update!(status: :reviewing, pending_items: pending)
    task = pending.find { |candidate| candidate["kind"] == "task" }

    revision = @session.edit_pending_item!(
      id: task.fetch("id"), fields: task.fetch("fields").merge("due_on" => ""), expected_revision: 0
    )
    @session.update_planning_details!(starts_on: "2027-04-01", expected_revision: revision)

    items = @session.reload.visible_pending_items
    assert_empty items.find { |candidate| candidate["kind"] == "task" }.dig("fields", "due_on")
    assert_equal "2027-04-10", items.find { |candidate| candidate["kind"] == "schedule_item" }.dig("fields", "date")
  end

  test "provider task offsets reject invalid values and unresolved valid offsets require an anchor" do
    @session.project.update!(starts_on: nil, ends_on: nil)

    [ "soon", 1_000, false ].each do |bad_offset|
      Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
        Planner::Response.new(card: nil, finished: true, added: [
          item("task", "relative-task", "title" => "Confirm crew", "details" => "", "due_in_days" => bad_offset)
        ], removed_ids: [])
      ])
      revision = @session.queue_generation!
      assert_not @session.generate!(revision:)
      assert_empty @session.reload.pending_items
    end

    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(card: nil, finished: true, added: [
        item("task", "relative-task", "title" => "Confirm crew", "details" => "", "due_in_days" => 5)
      ], removed_ids: [])
    ])
    revision = @session.queue_generation!
    assert @session.generate!(revision:), @session.reload.last_error
    task = @session.reload.visible_pending_items.sole
    assert_nil task.dig("fields", "due_on")
    assert @session.pending_item_errors.key?(task.fetch("id"))

    @session.update_planning_details!(starts_on: "2027-04-01", expected_revision: revision)
    assert_equal "2027-04-06", @session.reload.visible_pending_items.sole.dig("fields", "due_on")
    assert_empty @session.pending_item_errors
  end

  test "v2 rejects non-meal items without replacing its saved preview" do
    meal_session = @session.project.planner_sessions.create!(
      started_by: @leader, description: "Plan meals", flow_version: 2, planning_kind: "meal_train"
    )
    original = Planner::PendingItems.expand([
      item("slot_run", "meals", "label" => "Dinner", "start_date" => "2027-02-15", "end_date" => "2027-02-16", "time" => "17:30", "capacity" => 1)
    ], project: meal_session.project).map(&:to_h)
    meal_session.update!(pending_items: original)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(card: nil, finished: true, added: [
        item("task", "not-a-meal", "title" => "Call someone", "details" => "", "due_on" => nil)
      ], removed_ids: [])
    ])

    revision = meal_session.queue_generation!
    assert_not meal_session.generate!(revision:)
    assert_equal original, meal_session.reload.pending_items
    assert_equal "failed", meal_session.generation_state
  end

  test "a general plan can include four separate volunteer shifts" do
    shifts = 4.times.map do |index|
      item("slot_run", "shift-#{index}", "label" => "Shift #{index + 1}",
        "start_day_offset" => 0, "end_day_offset" => 0, "time" => "09:00", "capacity" => 2)
    end
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(card: nil, finished: true, added: shifts, removed_ids: [])
    ])
    revision = @session.queue_generation!
    assert @session.generate!(revision:), @session.reload.last_error
    assert_equal 4, @session.reload.pending_item_count
  end

  private
    def item(kind, source_key, fields)
      { "kind" => kind, "source_key" => source_key, "fields" => fields }
    end
end
