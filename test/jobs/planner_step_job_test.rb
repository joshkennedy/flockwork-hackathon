require "test_helper"

class PlannerStepJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  class RevokingProvider
    attr_reader :contexts

    def initialize(membership, response)
      @membership = membership
      @response = response
      @contexts = []
    end

    def call(context)
      contexts << context.deep_dup
      @membership.destroy!
      @response
    end
  end

  setup do
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "revision job without the enqueuing session does not use started_by visibility" do
    organization = organizations(:st_example)
    project = organization.projects.find(projects(:community_meal).id)
    hidden_project = organization.projects.find(projects(:building_cleanup).id)
    hidden_project.tasks.create!(title: "Confidential organ loft repair")
    planner_session = project.planner_sessions.create!(
      started_by: organization.people.find(people(:admin).id),
      description: "Plan a workday",
      flow_version: 3,
      planning_kind: "workday"
    )
    revision = planner_session.queue_generation!
    provider = Planner::Providers::Fake.new([
      Planner::Response.new(
        card: { "question" => "Pick one?", "options" => %w[a b c] },
        finished: false,
        added: [],
        removed_ids: []
      )
    ])
    Rails.configuration.x.planner_provider = provider

    PlannerStepJob.perform_now(
      project.id,
      planner_session.id,
      Session.maximum(:id).to_i + 1,
      people(:leader).id,
      revision
    )

    assert_not_includes provider.contexts.last.fetch("past_projects").to_json,
      "Confidential organ loft repair"
  end

  test "classic job skips generation after the enqueuing leader loses plan permission" do
    leader = people(:leader)
    project = leader.organization.projects.find(projects(:community_meal).id)
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    planner_session = project.planner_sessions.create!(
      started_by: leader,
      description: "Plan a workday",
      flow_version: 1,
      planning_kind: "workday"
    )
    provider = Planner::Providers::Fake.new([ planner_response ])
    Rails.configuration.x.planner_provider = provider
    project.memberships.find_by!(person: leader).destroy!

    PlannerStepJob.perform_now(project.id, planner_session.id, current_session.id, leader.id)

    assert_empty provider.contexts
  end

  test "revision job skips generation after the enqueuing leader loses plan permission" do
    leader = people(:leader)
    project = leader.organization.projects.find(projects(:community_meal).id)
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    planner_session = project.planner_sessions.create!(
      started_by: leader,
      description: "Plan a workday",
      flow_version: 3,
      planning_kind: "workday"
    )
    revision = planner_session.queue_generation!
    provider = Planner::Providers::Fake.new([ planner_response ])
    Rails.configuration.x.planner_provider = provider
    project.memberships.find_by!(person: leader).destroy!

    PlannerStepJob.perform_now(project.id, planner_session.id, current_session.id, leader.id, revision)

    assert_empty provider.contexts
  end

  test "classic job skips its broadcast when plan permission is revoked during generation" do
    leader = people(:leader)
    project = leader.organization.projects.find(projects(:community_meal).id)
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    membership = project.memberships.find_by!(person: leader)
    planner_session = project.planner_sessions.create!(
      started_by: leader,
      description: "Plan a workday",
      flow_version: 1,
      planning_kind: "workday"
    )
    provider = RevokingProvider.new(membership, planner_response)
    Rails.configuration.x.planner_provider = provider
    stream = PlannerStreamChannel.authorized_stream_name(planner_session)

    assert_no_broadcasts(stream) do
      PlannerStepJob.perform_now(project.id, planner_session.id, current_session.id, leader.id)
    end
    assert_equal 1, provider.contexts.size
  end

  private
    def planner_response
      Planner::Response.new(
        card: { "question" => "Pick one?", "options" => %w[a b c] },
        finished: false,
        added: [],
        removed_ids: []
      )
    end
end
