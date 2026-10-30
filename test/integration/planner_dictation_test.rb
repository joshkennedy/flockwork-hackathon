require "test_helper"

class PlannerDictationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
  end

  test "planner pages render hidden dictation buttons with accessible labels" do
    suggestion_id = "11111111-1111-4111-8111-111111111111"
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen before guests arrive?",
          "options" => [ "Set the room" ]
        },
        suggestions: []
      ),
      planner_response(
        finished: true,
        suggestions: [
          task_suggestion(suggestion_id, "Set up tables", "Arrange the dining room.")
        ]
      )
    ])
    sign_in_as_leader

    get new_project_planner_session_path(@project)
    assert_response :success
    assert_dictation_button

    post project_planner_sessions_path(@project), params: {
      planner_session: { description: "Plan the neighborhood meal." }
    }
    follow_redirect!
    assert_dictation_button

    post answer_project_planner_session_path(@project, @project.planner_sessions.last!), params: { answer: "Set the room" }
    follow_redirect!
    assert_response :success
    assert_select "[data-controller=?] button[hidden][aria-label=?]", "dictation", "Dictate", count: 2
  end

  private
    def assert_dictation_button
      assert_select "[data-controller=?] button[hidden][aria-label=?]", "dictation", "Dictate"
    end

    def planner_response(card: nil, finished: false, suggestions:)
      Planner::Response.new(card:, finished:, suggestions:)
    end

    def task_suggestion(id, title, details)
      {
        "id" => id,
        "kind" => "task",
        "fields" => { "title" => title, "details" => details },
        "status" => "proposed"
      }
    end
end
