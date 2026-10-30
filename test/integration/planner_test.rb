require "test_helper"
require "timeout"

class PlannerTest < ActionDispatch::IntegrationTest
  class RaisingProvider
    attr_reader :contexts

    def initialize
      @contexts = []
    end

    def call(context)
      contexts << context.deep_dup
      raise Timeout::Error, "Planner timed out"
    end
  end

  setup do
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
  end

  test "a Leader plans Tasks through cards and accepts only kept and edited Suggestions" do
    project = projects(:community_meal)
    setup_id = "11111111-1111-4111-8111-111111111111"
    welcome_id = "22222222-2222-4222-8222-222222222222"
    dropped_id = "33333333-3333-4333-8333-333333333333"
    fake = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen before guests arrive?",
          "options" => [ "Set the room", "Prepare food", "Welcome volunteers" ]
        },
        suggestions: []
      ),
      planner_response(
        card: {
          "question" => "What needs a clear owner?",
          "options" => [ "Room setup", "Kitchen prep", "Guest welcome" ]
        },
        suggestions: [ task_suggestion(setup_id, "Set up tables", "Arrange the dining room.") ]
      ),
      planner_response(
        finished: true,
        suggestions: [
          task_suggestion(setup_id, "Set up tables", "Arrange the dining room.", due_in_days: -1),
          task_suggestion(welcome_id, "Prepare welcome table", "Set out name tags."),
          task_suggestion(dropped_id, "Print decorative menus", "Use the color printer.")
        ]
      )
    ])
    Rails.configuration.x.planner_provider = fake
    sign_in_as_leader

    get new_project_planner_session_path(project)
    assert_response :success

    assert_difference "PlannerSession.count", 1 do
      post project_planner_sessions_path(project), params: {
        planner_session: { description: "Plan the final week before our neighborhood meal." }
      }
    end

    session = project.planner_sessions.order(:id).last!
    assert_redirected_to project_planner_session_path(project, session)

    follow_redirect!
    assert_select "h1", text: "What should happen before guests arrive?"

    post answer_project_planner_session_path(project, session), params: { answer: "Set the room" }
    assert_redirected_to project_planner_session_path(project, session)
    assert_equal [
      {
        question: "What should happen before guests arrive?",
        answer: "Set the room"
      }
    ], fake.contexts.second.fetch(:answers)

    follow_redirect!
    assert_select "h1", text: "What needs a clear owner?"

    post answer_project_planner_session_path(project, session), params: { answer: "Ask two volunteers to lead setup." }
    assert_redirected_to review_project_planner_session_path(project, session)

    patch suggestion_project_planner_session_path(project, session), params: {
      suggestion: { id: setup_id, decision: "keep" }
    }
    patch suggestion_project_planner_session_path(project, session), params: {
      suggestion: {
        id: welcome_id,
        decision: "edit",
        title: "Build the welcome station",
        details: "Put out name tags and markers."
      }
    }
    patch suggestion_project_planner_session_path(project, session), params: {
      suggestion: { id: dropped_id, decision: "drop" }
    }

    assert_difference "project.tasks.count", 2 do
      post accept_project_planner_session_path(project, session), params: { mode: "kept" }
    end

    assert_redirected_to project_path(project)
    assert_equal [ "Build the welcome station", "Set up tables" ], project.tasks.order(:title).pluck(:title)
    assert_nil project.tasks.find_by!(title: "Build the welcome station").assignee
    assert_equal Date.new(2027, 2, 11), project.tasks.find_by!(title: "Set up tables").due_on
    assert_not project.tasks.exists?(title: "Print decorative menus")
    assert_predicate session.reload, :accepted?
  end

  test "Planner contexts exclude People, Team, Recipients, and Messages" do
    project = projects(:community_meal)
    workspace = project.workspace
    team_person = workspace.people.create!(
      name: "Zebulon Privacy Sentinel",
      email: "zebulon.sentinel@example.test",
      phone: "+1-555-810-1818"
    )
    recipient_person = workspace.people.create!(
      name: "Xanthe Recipient Marker",
      email: "xanthe.marker@example.test",
      phone: "+1-555-810-1919"
    )
    project.memberships.create!(person: team_person, role: :volunteer)
    project.recipients.create!(person: recipient_person)
    project.messages.create!(author: team_person, body: "A private message from Zebulon Privacy Sentinel.")

    fake = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What work comes first?",
          "options" => [ "Setup", "Food", "Welcome" ]
        },
        suggestions: []
      )
    ])
    Rails.configuration.x.planner_provider = fake
    sign_in_as_leader

    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Plan the room setup and meal service." }
    }

    assert_redirected_to project_planner_session_path(project, project.planner_sessions.last!)
    assert_equal %i[
      project_name
      project_description
      leader_description
      answers
      enabled_tools
      existing_task_titles
      past_projects
      current_suggestions
    ], fake.contexts.first.keys

    context_json = fake.contexts.to_json
    [ team_person, recipient_person, people(:leader), people(:volunteer) ].each do |person|
      assert_not_includes context_json, person.name
      assert_not_includes context_json, person.email if person.email
      assert_not_includes context_json, person.phone if person.phone
    end
  end

  test "a provider timeout keeps the answer and lets the Leader leave or review" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should volunteers prepare?",
          "options" => [ "Tables", "Food", "Welcome signs" ]
        },
        suggestions: [
          task_suggestion(
            "44444444-4444-4444-8444-444444444444",
            "Set up tables",
            "Arrange twelve tables."
          )
        ]
      )
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Prepare the neighborhood meal." }
    }
    planner_session = project.planner_sessions.last!
    Rails.configuration.x.planner_provider = RaisingProvider.new

    assert_no_difference "project.tasks.count" do
      post answer_project_planner_session_path(project, planner_session), params: { answer: "Tables" }
    end

    assert_redirected_to project_planner_session_path(project, planner_session)
    follow_redirect!
    assert_select "[role='alert']", text: PlannerSession::ERROR_MESSAGE
    assert_select "a", text: "Skip to review"
    assert_select "a", text: "Leave Planner"
    assert_equal [
      {
        "question" => "What should volunteers prepare?",
        "options" => [ "Tables", "Food", "Welcome signs" ],
        "answer" => "Tables"
      }
    ], planner_session.reload.steps
    assert_equal "Planner timed out", planner_session.last_error
    assert_equal "Set up tables", planner_session.suggestions.first.dig("fields", "title")

    post skip_to_review_project_planner_session_path(project, planner_session)
    assert_redirected_to review_project_planner_session_path(project, planner_session)
  end

  test "a Volunteer cannot start the Planner" do
    project = projects(:community_meal)
    sign_in_as_volunteer

    get project_path(project)
    assert_response :success
    assert_select "a", text: "Plan with AI", count: 0

    get new_project_planner_session_path(project)
    assert_response :not_found

    assert_no_difference "PlannerSession.count" do
      post project_planner_sessions_path(project), params: {
        planner_session: { description: "A Volunteer should not start this." }
      }
    end
    assert_response :not_found
  end

  test "Accept all treats proposed Suggestions as kept" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        finished: true,
        suggestions: [
          task_suggestion(
            "55555555-5555-4555-8555-555555555555",
            "Confirm the serving plan",
            "Review the order of service with the Team."
          )
        ]
      )
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Finish the serving plan." }
    }
    planner_session = project.planner_sessions.last!

    assert_redirected_to review_project_planner_session_path(project, planner_session)
    assert_difference "project.tasks.count", 1 do
      post accept_project_planner_session_path(project, planner_session), params: { mode: "all" }
    end

    assert_redirected_to project_path(project)
    assert_equal "Confirm the serving plan", project.tasks.last!.title
    assert_equal "kept", planner_session.reload.suggestions.first.fetch("status")
  end

  private
    def planner_response(card: nil, finished: false, suggestions:)
      Planner::Response.new(card:, finished:, suggestions:)
    end

    def task_suggestion(id, title, details, due_in_days: nil)
      fields = { "title" => title, "details" => details }
      fields["due_in_days"] = due_in_days unless due_in_days.nil?
      {
        "id" => id,
        "kind" => "task",
        "fields" => fields,
        "status" => "proposed"
      }
    end
end
