require "test_helper"

class PlannerSessionTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "a delta adds a new Suggestion with a generated id and proposed status" do
    planner_session = apply_delta(
      added: [ added_task_suggestion("Prepare the room").merge("ignored" => "junk") ]
    )

    suggestion = planner_session.suggestions.first
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, suggestion.fetch("id"))
    assert_equal "Prepare the room", suggestion.dig("fields", "title")
    assert_equal "proposed", suggestion.fetch("status")
    assert_equal %w[fields id kind status], suggestion.keys.sort
    assert_predicate planner_session, :reviewing?
  end

  test "removed_ids removes a proposed Suggestion" do
    suggestion_id = "66666666-6666-4666-8666-666666666666"
    planner_session = apply_delta(
      existing: [ stored_task_suggestion(suggestion_id, "Prepare the room") ],
      removed_ids: [ suggestion_id ]
    )

    assert_empty planner_session.suggestions
  end

  test "removed_ids cannot remove Suggestions the Leader kept or edited" do
    kept_id = "77777777-7777-4777-8777-777777777777"
    edited_id = "88888888-8888-4888-8888-888888888888"
    planner_session = apply_delta(
      existing: [
        stored_task_suggestion(kept_id, "Keep the room ready", status: "kept"),
        stored_task_suggestion(edited_id, "Edit the pantry plan", status: "edited")
      ],
      removed_ids: [ kept_id, edited_id ]
    )

    assert_equal [ kept_id, edited_id ], planner_session.suggestions.map { |suggestion| suggestion.fetch("id") }
    assert_equal %w[kept edited], planner_session.suggestions.map { |suggestion| suggestion.fetch("status") }
  end

  test "an unknown removed id is ignored" do
    suggestion_id = "99999999-9999-4999-8999-999999999999"
    planner_session = apply_delta(
      existing: [ stored_task_suggestion(suggestion_id, "Stock the pantry") ],
      removed_ids: [ "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" ]
    )

    assert_equal [ suggestion_id ], planner_session.suggestions.map { |suggestion| suggestion.fetch("id") }
  end

  test "unknown added kinds are dropped and known fields are sanitized" do
    planner_session = apply_delta(
      added: [
        {
          "kind" => "unknown_kind",
          "fields" => { "title" => "Ignore me", "extra" => "junk" }
        },
        {
          "kind" => "task",
          "fields" => {
            "title" => "Stock the pantry",
            "details" => "Gather supplies.",
            "extra" => "junk",
            "due_in_days" => nil
          }
        }
      ]
    )

    assert_equal 1, planner_session.suggestions.size
    suggestion = planner_session.suggestions.sole
    assert_equal "task", suggestion.fetch("kind")
    assert_equal(
      { "title" => "Stock the pantry", "details" => "Gather supplies." },
      suggestion.fetch("fields")
    )
  end

  private
    def apply_delta(existing: [], added: [], removed_ids: [])
      Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
        Planner::Response.new(card: nil, finished: true, added:, removed_ids:)
      ])
      leader = people(:leader)
      current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
      planner_session = projects(:community_meal).planner_sessions.create!(
        started_by: leader,
        description: "Prepare the room for the meal.",
        suggestions: existing
      )

      Current.set(session: current_session) { planner_session.run_step! }
      planner_session.reload
    end

    def added_task_suggestion(title)
      {
        "kind" => "task",
        "fields" => { "title" => title, "details" => "Set up chairs and tables." }
      }
    end

    def stored_task_suggestion(id, title, status: "proposed")
      {
        "id" => id,
        "kind" => "task",
        "fields" => { "title" => title, "details" => "Set up chairs and tables." },
        "status" => status
      }
    end
end
