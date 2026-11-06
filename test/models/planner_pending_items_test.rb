require "test_helper"

class PlannerPendingItemsTest < ActiveSupport::TestCase
  setup do
    @project = projects(:community_meal)
  end

  test "a changed series identity cannot replace removed work" do
    removed = reconcile(added: [ slot_run(source_key: "meal-slots") ]).map do |item|
      item.merge("removed" => true)
    end

    error = assert_raises(ArgumentError) do
      reconcile(existing: removed, added: [ slot_run(source_key: "replacement-slots") ])
    end
    assert_equal "Meal series identity changed; the existing preview was preserved", error.message
  end

  test "creating pending work updates a Project collection that is already loaded" do
    @project.slots.load
    original_ids = @project.slots.map(&:id)
    item = {
      "kind" => "slot",
      "fields" => { "label" => "Bring dinner", "date" => "2027-03-01", "time" => "18:30", "capacity" => 2 }
    }

    created = Planner::PendingItems.create!(@project, item)

    assert_equal original_ids + [ created.id ], @project.slots.map(&:id)
    assert_equal "Bring dinner", @project.slots.last.label
    assert_equal 2, @project.slots.last.capacity
    assert_equal Date.new(2027, 3, 1), @project.slots.last.date
  end

  test "duplicate series identities are rejected" do
    error = assert_raises(ArgumentError) do
      reconcile(added: [ slot_run(source_key: "meal-slots"), slot_run(source_key: "meal-slots") ])
    end
    assert_equal "Duplicate meal series", error.message
  end

  test "an undated series cannot exceed the sixty day preview boundary" do
    error = assert_raises(ArgumentError) do
      reconcile(added: [ slot_run(start_day_offset: 0, end_day_offset: 60) ])
    end
    assert_equal "Meal offsets must be within 60 days", error.message
  end

  test "an unresolved field conflict survives an identical later snapshot" do
    original = reconcile(added: [ slot_run(time: "17:30") ])
    edited = original.map do |item|
      item.deep_merge(
        "fields" => { "time" => "18:30" },
        "user_edits" => { "time" => "18:30" }
      )
    end
    conflicted = reconcile(existing: edited, added: [ slot_run(time: "19:00") ])

    assert_equal "field_changes", conflicted.first.dig("conflict", "type")
    assert_equal "19:00", conflicted.first.dig("conflict", "fields", "time", "suggested")

    repeated = reconcile(existing: conflicted, added: [ slot_run(time: "19:00") ])
    assert_equal conflicted.first.fetch("conflict"), repeated.first.fetch("conflict")
    assert_equal "18:30", repeated.first.dig("fields", "time")
  end

  test "only explicit removals drop saved work and Leader edits still win" do
    existing = reconcile(added: [ slot_run ])
    omitted = reconcile(existing:, added: [])

    assert_equal existing, omitted

    id = existing.first.fetch("id")
    assert_equal 2, reconcile(existing:, added: [], removed_ids: [ id ]).size

    edited = existing.map(&:deep_dup)
    edited.first["fields"]["time"] = "18:30"
    edited.first["user_edits"]["time"] = "18:30"
    preserved = reconcile(existing: edited, added: [], removed_ids: [ id ])

    assert_equal 3, preserved.size
    assert_equal "18:30", preserved.first.dig("fields", "time")
    assert_equal "removed_by_revision", preserved.first.dig("conflict", "type")
  end

  test "a revised undated offset is used when the first date is supplied later" do
    @project.update!(starts_on: nil, ends_on: nil)
    original = reconcile(added: [ slot_run(start_day_offset: 0, end_day_offset: 0) ])
    revised = reconcile(
      existing: original,
      added: [ slot_run(start_day_offset: 4, end_day_offset: 4) ]
    )

    assert_equal 4, revised.first.fetch("day_offset")
    assert_nil revised.first.dig("fields", "date")

    planner_session = @project.planner_sessions.create!(
      started_by: people(:leader),
      description: "Plan meals",
      flow_version: 2,
      pending_items: revised
    )
    planner_session.update_planning_details!(starts_on: "2027-03-01", expected_revision: 0)

    assert_equal "2027-03-05", planner_session.reload.pending_items.first.dig("fields", "date")
  end

  private
    def reconcile(existing: [], added:, removed_ids: [])
      Planner::PendingItems.reconcile(
        existing:,
        added:,
        removed_ids:,
        project: @project
      )
    end

    def slot_run(source_key: "meal-slots", start_day_offset: 0, end_day_offset: 2, time: "17:30")
      {
        "kind" => "slot_run",
        "source_key" => source_key,
        "fields" => {
          "label" => "Bring dinner",
          "start_day_offset" => start_day_offset,
          "end_day_offset" => end_day_offset,
          "time" => time,
          "capacity" => 1
        }
      }
    end
end

class PlannerMalformedResponseTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @planner_session = projects(:community_meal).planner_sessions.create!(
      started_by: people(:leader),
      description: "Plan meals",
      flow_version: 2,
      pending_items: Planner::PendingItems.expand(
        [ dated_slot_run ], project: projects(:community_meal)
      ).map(&:to_h)
    )
    @browser_session = people(:leader).sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "a malformed next card fails generation without replacing the preview" do
    original_preview = @planner_session.pending_items.deep_dup
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(card: { "options" => [ "Dinner" ] }, finished: false, added: [], removed_ids: [])
    ])
    revision = @planner_session.queue_generation!

    assert_not Current.set(session: @browser_session) { @planner_session.generate!(revision:) }
    @planner_session.reload
    assert_equal "failed", @planner_session.generation_state
    assert_equal original_preview, @planner_session.pending_items
    assert_match(/question/i, @planner_session.last_error)
  end

  private
    def dated_slot_run
      {
        "kind" => "slot_run",
        "source_key" => "meal-slots",
        "fields" => {
          "label" => "Bring dinner",
          "start_date" => "2027-02-15",
          "end_date" => "2027-02-15",
          "time" => "17:30",
          "capacity" => 1
        }
      }
    end
end
