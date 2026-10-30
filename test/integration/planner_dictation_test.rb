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
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen before guests arrive?",
          "options" => [ "Set the room" ]
        }
      ),
      planner_response(
        finished: true,
        added: [
          task_suggestion("Set up tables", "Arrange the dining room.")
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

    planner_session = @project.planner_sessions.last!
    perform_enqueued_jobs do
      post answer_project_planner_session_path(@project, planner_session), params: { answer: "Set the room" }
    end
    get review_project_planner_session_path(@project, planner_session)
    assert_response :success
    assert_select "[data-controller=?] button[hidden][aria-label=?]", "dictation", "Dictate", minimum: 1
  end

  private
    def assert_dictation_button
      assert_select "[data-controller=?] button[hidden][aria-label=?]", "dictation", "Dictate"
    end

    def planner_response(card: nil, finished: false, added: [], removed_ids: [])
      Planner::Response.new(card:, finished:, added:, removed_ids:)
    end

    def task_suggestion(title, details)
      {
        "kind" => "task",
        "fields" => { "title" => title, "details" => details }
      }
    end
end
