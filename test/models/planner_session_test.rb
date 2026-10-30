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
