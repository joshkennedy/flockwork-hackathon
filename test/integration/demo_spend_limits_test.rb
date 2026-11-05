require "test_helper"
require_relative "../support/method_stubs"

class DemoSpendLimitsTest < ActionDispatch::IntegrationTest
  include MethodStubs

  class CountingPlannerProvider
    attr_reader :calls

    def initialize(response, responses: nil)
      @calls = 0
      @fake = Planner::Providers::Fake.new(responses || [ response ])
    end

    def call(context, &on_partial)
      @calls += 1
      @fake.call(context, &on_partial)
    end
  end

  class CountingVoiceMinter
    attr_reader :calls

    def initialize(secret = "voice-test-secret")
      @calls = 0
      @secret = secret
    end

    def call
      @calls += 1
      @secret
    end
  end

  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_minter = Rails.configuration.x.voice_client_secret_minter
    DemoOrganization.seed!
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Rails.configuration.x.voice_client_secret_minter = @original_minter
  end

  test "planner create is bounded per person" do
    post demo_session_path(role: "leader")
    maria = people(:grace_leader)
    project = maria.memberships.leader.first!.project
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      10.times do
        post project_planner_sessions_path(project), params: { planner_session: { description: "Plan the next step." } }
        assert_response :redirect
      end
      assert_no_difference "PlannerSession.count" do
        post project_planner_sessions_path(project), params: { planner_session: { description: "One more plan." } }
      end
      assert_redirected_to new_project_planner_session_path(project)
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 10, provider.calls
    end
  end

  test "start planner is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        10.times do
          post start_planner_projects_path, params: { planning_kind: "workday" }
          assert_response :see_other
        end
      end
      assert_equal 10, provider.calls
      assert_no_difference [ "Project.count", "PlannerSession.count" ] do
        perform_enqueued_jobs(only: PlannerStepJob) do
          post start_planner_projects_path, params: { planning_kind: "workday" }
        end
      end
      assert_redirected_to new_project_path
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 10, provider.calls
    end
  end

  test "start meal planner is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        10.times do
          post start_meal_planner_projects_path
          assert_response :see_other
        end
      end
      assert_equal 0, provider.calls
      assert_no_difference [ "Project.count", "PlannerSession.count" ] do
        perform_enqueued_jobs(only: PlannerStepJob) do
          post start_meal_planner_projects_path
        end
      end
      assert_redirected_to new_project_path
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 0, provider.calls
    end
  end

  test "retry generation is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        post start_planner_projects_path, params: { planning_kind: "workday" }
      end
      project = PlannerSession.order(:id).last!.project
      planner_session = PlannerSession.order(:id).last!
      perform_enqueued_jobs(only: PlannerStepJob) do
        9.times do
          post retry_generation_project_planner_session_path(project, planner_session),
            params: { expected_revision: planner_session.reload.generation_revision }
          assert_response :see_other
        end
      end
      assert_equal 10, provider.calls
      perform_enqueued_jobs(only: PlannerStepJob) do
        post retry_generation_project_planner_session_path(project, planner_session),
          params: { expected_revision: planner_session.reload.generation_revision }
      end
      assert_redirected_to new_project_planner_session_path(project)
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 10, provider.calls
    end
  end

  test "select answer is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    card_response = planner_response(
      card: { "question" => "What matters most?", "options" => [ "Food", "Setup", "Cleanup" ] }
    )
    provider = CountingPlannerProvider.new(
      card_response, responses: Array.new(70) { card_response }
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        post start_planner_projects_path, params: { planning_kind: "workday" }
      end
      project = PlannerSession.order(:id).last!.project
      planner_session = PlannerSession.order(:id).last!
      assert_equal 1, provider.calls

      60.times do
        perform_enqueued_jobs(only: PlannerStepJob) do
          post select_answer_project_planner_session_path(project, planner_session),
            params: {
              answer: "Food",
              step_index: 0,
              expected_revision: planner_session.reload.generation_revision
            }
          assert_response :see_other
        end
      end
      assert_equal 61, provider.calls

      perform_enqueued_jobs(only: PlannerStepJob) do
        post select_answer_project_planner_session_path(project, planner_session),
          params: {
            answer: "Food",
            step_index: 0,
            expected_revision: planner_session.reload.generation_revision
          }
      end
      assert_redirected_to new_project_planner_session_path(project)
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 61, provider.calls
    end
  end

  test "voice session mint is not blocked by planner create quota" do
    post demo_session_path(role: "leader")
    maria = people(:grace_leader)
    project = maria.memberships.leader.first!.project
    minter = CountingVoiceMinter.new
    Rails.configuration.x.voice_client_secret_minter = minter
    with_rate_limit_store do
      10.times do
        post project_planner_sessions_path(project), params: { planner_session: { description: "Plan the next step." } }
        assert_response :redirect
      end
      planner_session = project.planner_sessions.order(:id).last!
      post voice_session_project_planner_session_path(project, planner_session), as: :json
      assert_response :success
      assert_equal 1, minter.calls
    end
  end

  test "voice session mint is bounded per person" do
    post demo_session_path(role: "leader")
    maria = people(:grace_leader)
    project = maria.memberships.leader.first!.project
    minter = CountingVoiceMinter.new
    Rails.configuration.x.voice_client_secret_minter = minter
    planner_session = project.planner_sessions.create!(
      started_by: maria,
      description: "Prepare the meal.",
      current_card: { "question" => "What first?", "options" => [ "Cook", "Set up" ] }
    )
    with_rate_limit_store do
      10.times do
        post voice_session_project_planner_session_path(project, planner_session), as: :json
        assert_response :success
      end
      post voice_session_project_planner_session_path(project, planner_session), as: :json
      assert_response :too_many_requests
      assert_equal 10, minter.calls
    end
  end

  private
    def with_rate_limit_store
      store = ActiveSupport::Cache::MemoryStore.new
      increment = ->(*args, **kwargs) { store.increment(*args, **kwargs) }
      stub_method(PlannerSessionsController.cache_store, :increment, increment) do
        stub_method(ProjectsController.cache_store, :increment, increment) do
          yield
        end
      end
    end

    def planner_response(card: nil, finished: false, added: [], removed_ids: [])
      Planner::Response.new(card:, finished:, added:, removed_ids:)
    end
end
