require "test_helper"

class PlannerMealSessionTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @leader = people(:leader)
    @browser_session = @leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    @planner_session = projects(:community_meal).planner_sessions.create!(
      started_by: @leader,
      description: "Organize a meal train",
      flow_version: 2
    )
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "generation yields streamed snapshots before the final preview is saved" do
    use_provider(response(card: card("Which meals?"), added: [ slot_run ]))
    snapshots = []

    revision = @planner_session.queue_generation!
    assert current { @planner_session.generate!(revision:) { |partial| snapshots << partial } }

    assert_equal "Which meals?", snapshots.last.fetch(:card).fetch("question")
    assert_predicate @planner_session.reload.visible_pending_items, :any?
  end

  test "initial generation publishes the first card and answer generation waits for Continue" do
    provider = use_provider(
      response(card: card("Which meals?")),
      response(card: card("For how long?"), added: [ slot_run ])
    )

    revision = @planner_session.queue_generation!
    assert current { @planner_session.generate!(revision:) }
    assert_equal "Which meals?", @planner_session.reload.current_card.fetch("question")
    assert_equal "idle", @planner_session.generation_state

    revision = current { @planner_session.select_answer!("Dinner", expected_revision: revision) }
    assert current { @planner_session.generate!(revision:) }
    @planner_session.reload
    assert_equal "Which meals?", @planner_session.current_card.fetch("question")
    assert_equal "For how long?", @planner_session.prepared_card.fetch("question")
    assert_predicate @planner_session, :ready_to_continue?
    assert_equal 2, @planner_session.pending_item_count

    assert_no_changes -> { provider.contexts.size } do
      @planner_session.continue!(expected_revision: revision)
    end
    assert_equal "For how long?", @planner_session.reload.current_card.fetch("question")
  end

  test "a stale generation never calls the provider or changes state" do
    provider = use_provider(response(card: card("Unused")))
    revision = @planner_session.queue_generation!
    @planner_session.update!(generation_revision: revision + 1)

    assert_not @planner_session.generate!(revision:)
    assert_empty provider.contexts
    assert_nil @planner_session.reload.current_card
  end

  test "reselecting a pending answer replaces the same step" do
    use_provider(
      response(card: card("Which meals?")),
      response(card: card("For how long?"))
    )
    revision = generate_initial
    revision = current { @planner_session.select_answer!("Dinner", expected_revision: revision) }
    assert current { @planner_session.generate!(revision:) }
    revision = current { @planner_session.select_answer!("Lunch", expected_revision: revision) }

    assert_equal 1, @planner_session.reload.steps.size
    assert_equal "Lunch", @planner_session.steps.first.fetch("answer")
    assert_equal 0, @planner_session.pending_answer.fetch("step_index")
  end

  test "revising an earlier answer returns a reviewing session to asking" do
    @planner_session.update!(
      status: :reviewing,
      steps: [ { "question" => "Which meals?", "options" => [ "Dinner" ], "answer" => "Dinner" } ]
    )

    current { @planner_session.select_answer!("Lunch", expected_revision: 0, step_index: 0) }

    assert_predicate @planner_session.reload, :asking?
    assert_equal "queued", @planner_session.generation_state
  end

  test "an undated run creates visible occurrences that acceptance rejects until dated" do
    @planner_session.project.update!(starts_on: nil)
    run = slot_run.except("source_key")
    run["source_key"] = "meal-slots"
    run["fields"] = run.fetch("fields").except("start_date", "end_date").merge(
      "start_day_offset" => 0, "end_day_offset" => 1
    )
    use_provider(response(card: nil, finished: true, added: [ run ]))
    generate_initial

    assert_equal [ nil, nil ], @planner_session.pending_items.map { |item| item.dig("fields", "date") }
    assert_equal [ 0, 1 ], @planner_session.pending_items.map { |item| item.fetch("day_offset") }
    assert_raises(ActiveRecord::RecordInvalid) { @planner_session.accept_visible! }
  end

  test "pending mutations are rejected while generation is busy" do
    @planner_session.update!(generation_state: "running", pending_items: [
      Planner::PendingItems.expand([ slot_run ], project: @planner_session.project).first.to_h
    ])

    assert_raises(ArgumentError) do
      @planner_session.remove_pending_item!(
        id: @planner_session.pending_items.first.fetch("id"), expected_revision: 0
      )
    end
    assert_equal 0, @planner_session.reload.generation_revision
  end

  test "discard invalidates queued work without losing the saved preview" do
    item = Planner::PendingItems.expand([ slot_run ], project: @planner_session.project).first.to_h
    @planner_session.update!(generation_state: "queued", generation_revision: 4, pending_items: [ item ])

    @planner_session.abandon!

    @planner_session.reload
    assert_predicate @planner_session, :abandoned?
    assert_equal 5, @planner_session.generation_revision
    assert_equal "idle", @planner_session.generation_state
    assert_equal [ item ], @planner_session.pending_items
  end

  test "using a suggestion resolves a removed-by-revision conflict by removing the occurrence" do
    existing = Planner::PendingItems.expand([ slot_run ], project: @planner_session.project).map(&:to_h)
    second = existing.second
    second["fields"]["time"] = "18:30"
    second["user_edits"]["time"] = "18:30"
    @planner_session.update!(
      pending_items: existing,
      generation_state: "running",
      generation_revision: 1
    )
    response = response(
      card: card("When?"),
      added: [ slot_run.merge("fields" => slot_run.fetch("fields").merge("end_date" => "2027-02-12")) ]
    )

    assert @planner_session.send(:apply_generation!, revision: 1, response:)
    conflict = @planner_session.reload.pending_items.second
    assert_equal "removed_by_revision", conflict.dig("conflict", "type")

    revision = @planner_session.resolve_pending_conflict!(
      id: conflict.fetch("id"), choice: "use_suggestion", expected_revision: 1
    )
    assert_equal 2, revision
    assert_equal true, @planner_session.reload.pending_items.second.fetch("removed")
  end

  test "full snapshot reconciliation preserves occurrence edits and removals by index" do
    use_provider(
      response(card: card("For how long?"), added: [ slot_run ]),
      response(card: card("When?"), added: [ slot_run(label: "Lunch", start_date: "2027-02-14") ])
    )
    revision = generate_initial
    first, second = @planner_session.reload.visible_pending_items
    revision = @planner_session.edit_pending_item!(
      id: first.fetch("id"), fields: { "time" => "18:30" }, expected_revision: revision
    )
    revision = @planner_session.remove_pending_item!(id: second.fetch("id"), expected_revision: revision)

    @planner_session.update!(current_card: card("Which meals?"), generation_state: "idle")
    revision = current { @planner_session.select_answer!("Lunch", expected_revision: revision) }
    assert current { @planner_session.generate!(revision:) }
    first_after, second_after = @planner_session.reload.pending_items

    assert_equal first.fetch("id"), first_after.fetch("id")
    assert_equal "18:30", first_after.dig("fields", "time")
    assert_equal "Lunch", first_after.dig("fields", "label")
    assert_equal true, second_after.fetch("removed")
    assert_nil first_after.fetch("conflict")
  end

  test "planning date changes rebase suggested dates but preserve an edited occurrence date" do
    @planner_session.project.update!(starts_on: Date.new(2027, 2, 12))
    use_provider(response(card: card("For how long?"), added: [ slot_run ]))
    revision = generate_initial
    first, second = @planner_session.reload.pending_items
    revision = @planner_session.edit_pending_item!(
      id: second.fetch("id"), fields: { "date" => "2027-02-20" }, expected_revision: revision
    )

    revision = @planner_session.update_planning_details!(
      name: "Meals for the Parkers", starts_on: "2027-02-15", expected_revision: revision
    )

    @planner_session.reload
    assert_equal "Meals for the Parkers", @planner_session.project.reload.name
    assert_equal Date.new(2027, 2, 15), @planner_session.project.starts_on
    assert_equal "2027-02-15", @planner_session.pending_items.first.dig("fields", "date")
    assert_equal "2027-02-20", @planner_session.pending_items.second.dig("fields", "date")
    assert_equal @planner_session.generation_revision, revision
  end

  test "acceptance creates visible slots atomically and is idempotent" do
    use_provider(response(card: nil, finished: true, added: [ slot_run ]))
    generate_initial

    assert_difference "@planner_session.project.slots.count", 2 do
      receipt = @planner_session.accept_visible!
      assert_equal 2, receipt.fetch("item_count")
    end
    assert_no_difference "@planner_session.project.slots.count" do
      @planner_session.accept_visible!
    end
    assert_predicate @planner_session.reload, :accepted?
    assert_not_nil @planner_session.accepted_at
  end

  private
    def generate_initial
      revision = @planner_session.queue_generation!
      assert current { @planner_session.generate!(revision:) }
      revision
    end

    def use_provider(*responses)
      Planner::Providers::Fake.new(responses).tap do |provider|
        Rails.configuration.x.planner_provider = provider
      end
    end

    def response(card:, finished: false, added: [])
      Planner::Response.new(card:, finished:, added:, removed_ids: [])
    end

    def card(question)
      { "question" => question, "options" => [ "One", "Two", "Three" ] }
    end

    def slot_run(label: "Dinner", start_date: "2027-02-12", time: "17:30")
      {
        "kind" => "slot_run",
        "source_key" => "meal-slots",
        "fields" => {
          "label" => label,
          "start_date" => start_date,
          "end_date" => (Date.iso8601(start_date) + 1).iso8601,
          "time" => time,
          "capacity" => 1
        }
      }
    end

    def current(&block)
      Current.set(session: @browser_session, &block)
    end
end
