require "test_helper"
require_relative "../support/method_stubs"

class DemoSpendLimitsTest < ActionDispatch::IntegrationTest
  include MethodStubs

  class CountingPlannerProvider
    attr_reader :calls

    def initialize(response)
      @calls = 0
      @fake = Planner::Providers::Fake.new([ response ])
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
    store = ActiveSupport::Cache::MemoryStore.new
    stub_method(PlannerSessionsController.cache_store, :increment, ->(*args, **kwargs) { store.increment(*args, **kwargs) }) do
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
    store = ActiveSupport::Cache::MemoryStore.new
    stub_method(PlannerSessionsController.cache_store, :increment, ->(*args, **kwargs) { store.increment(*args, **kwargs) }) do
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
    def planner_response(card: nil, finished: false, added: [], removed_ids: [])
      Planner::Response.new(card:, finished:, added:, removed_ids:)
    end
end
