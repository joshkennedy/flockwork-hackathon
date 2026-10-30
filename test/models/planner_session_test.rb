require "test_helper"

class PlannerSessionTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "a matching updated Suggestion preserves the Leader's decision" do
    suggestion_id = "66666666-6666-4666-8666-666666666666"
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(
        card: {
          "question" => "What should happen first?",
          "options" => [ "Prepare", "Invite", "Review" ]
        },
        finished: false,
        suggestions: [ task_suggestion(suggestion_id, "Prepare the room") ]
      ),
      Planner::Response.new(
        card: nil,
        finished: true,
        suggestions: [ task_suggestion(suggestion_id, "Prepare the main room") ]
      )
    ])
    leader = people(:leader)
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    planner_session = projects(:community_meal).planner_sessions.create!(
      started_by: leader,
      description: "Prepare the room for the meal."
    )

    Current.set(session: current_session) do
      planner_session.start!
      planner_session.decide_suggestion!(id: suggestion_id, decision: "keep")
      planner_session.answer!("Prepare")
    end

    suggestion = planner_session.reload.suggestions.first
    assert_equal "Prepare the main room", suggestion.dig("fields", "title")
    assert_equal "kept", suggestion.fetch("status")
    assert_predicate planner_session, :reviewing?
  end

  test "apply_response drops unknown kinds and junk fields from provider suggestions" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(
        card: nil,
        finished: true,
        suggestions: [
          {
            "id" => "77777777-7777-4777-8777-777777777777",
            "kind" => "unknown_kind",
            "fields" => { "title" => "Ignore me", "extra" => "junk" },
            "status" => "proposed"
          },
          task_suggestion("88888888-8888-4888-8888-888888888888", "Stock the pantry")
            .merge("fields" => {
              "title" => "Stock the pantry",
              "details" => "Gather supplies.",
              "extra" => "junk",
              "due_in_days" => nil
            })
        ]
      )
    ])
    leader = people(:leader)
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    planner_session = projects(:community_meal).planner_sessions.create!(
      started_by: leader,
      description: "Stock the pantry for the meal."
    )

    Current.set(session: current_session) { planner_session.start! }

    assert_equal 1, planner_session.reload.suggestions.size
    suggestion = planner_session.suggestions.sole
    assert_equal "task", suggestion.fetch("kind")
    assert_equal(
      { "title" => "Stock the pantry", "details" => "Gather supplies." },
      suggestion.fetch("fields")
    )
  end

  private
    def task_suggestion(id, title)
      {
        "id" => id,
        "kind" => "task",
        "fields" => { "title" => title, "details" => "Set up chairs and tables." },
        "status" => "proposed"
      }
    end
end
