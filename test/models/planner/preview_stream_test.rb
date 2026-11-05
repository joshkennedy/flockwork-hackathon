require "test_helper"

class PlannerPreviewStreamTest < ActiveSupport::TestCase
  setup do
    @leader = people(:leader)
    @planner_session = projects(:community_meal).planner_sessions.create!(
      started_by: @leader, description: "Organize a meal train", flow_version: 2
    )
    @broadcasts = []
  end

  test "throttles item renders, sends the card once, and never persists partial state" do
    now = 0.0
    stream = Planner::PreviewStream.new(@planner_session, clock: -> { now })
    card = { "question" => "Which meals?", "options" => %w[Dinner Lunch Brunch] }
    slot = slot_run("Dinner")
    slot_two = slot_run("Lunch")

    with_broadcasts do
      stream.push(card:, added: [])
      stream.push(card:, added: [ slot ])
      now = 0.1
      stream.push(card:, added: [ slot, slot_two ])
      now = 0.3
      stream.push(card:, added: [ slot, slot_two ])
      stream.push(card:, added: [ slot, slot_two ])
    end

    # The card goes out once; items wait out the throttle, then land once with both slots.
    assert_equal [ "planner_sessions/meal_builder", "planner_sessions/meal_preview" ],
      @broadcasts.map { |broadcast| broadcast.fetch(:partial) }
    assert_equal 2, @broadcasts.last.dig(:locals, :visible_items).size
    assert_nil @planner_session.reload.current_card
    assert_empty @planner_session.reload.visible_pending_items
  end

  test "a prepared question waiting for Continue is not shown while the answer streams" do
    @planner_session.update!(pending_answer: { "text" => "Dinner", "step_index" => 0 })
    stream = Planner::PreviewStream.new(@planner_session, clock: -> { 0.0 })

    with_broadcasts do
      stream.push(card: { "question" => "How long?", "options" => %w[A B C] }, added: [ slot_run("Dinner") ])
    end

    assert_equal [ "planner_sessions/meal_preview" ], @broadcasts.map { |broadcast| broadcast.fetch(:partial) }
  end

  test "a malformed streamed item skips the render instead of failing the job" do
    stream = Planner::PreviewStream.new(@planner_session, clock: -> { 0.0 })

    with_broadcasts do
      stream.push(card: nil, added: [ { "kind" => "task", "source_key" => "tasks", "fields" => "not fields" } ])
    end

    assert_empty @broadcasts
  end

  test "a partial retry preview includes saved items that were not explicitly removed" do
    saved = [ slot_run("Dinner"), slot_run("Lunch"), slot_run("Brunch") ]
    @planner_session.update!(
      pending_items: Planner::PendingItems.expand(saved, project: @planner_session.project).map(&:to_h)
    )
    stream = Planner::PreviewStream.new(@planner_session, clock: -> { 0.0 })

    with_broadcasts do
      stream.push(card: nil, added: [ saved.first ])
    end

    streamed_items = @broadcasts.sole.dig(:locals, :visible_items)
    assert_equal @planner_session.pending_item_count, streamed_items.size
    assert_equal 3, streamed_items.size
  end

  test "does not broadcast a partial after Planner authority is revoked" do
    stream = Planner::PreviewStream.new(@planner_session, clock: -> { 0.0 }, authorized: -> { false })

    with_broadcasts do
      stream.push(card: { "question" => "Which meals?", "options" => %w[Dinner Lunch Brunch] },
        added: [ slot_run("Dinner") ])
    end

    assert_empty @broadcasts
  end

  private
    def slot_run(label)
      { "kind" => "slot_run", "source_key" => "meal-slots-#{label.downcase}",
        "fields" => { "label" => label, "start_day_offset" => 0, "end_day_offset" => 0, "time" => nil, "capacity" => 1 } }
    end

    def with_broadcasts
      singleton = Turbo::StreamsChannel.singleton_class
      singleton.alias_method(:original_replace_for_test, :broadcast_replace_to)
      broadcasts = @broadcasts
      singleton.define_method(:broadcast_replace_to) { |_stream, **options| broadcasts << options }
      yield
    ensure
      singleton.alias_method(:broadcast_replace_to, :original_replace_for_test)
      singleton.remove_method(:original_replace_for_test)
    end
end
