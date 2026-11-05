require "test_helper"
require "action_cable/channel/test_case"

class PlannerStreamRevocationTest < ActionDispatch::IntegrationTest
  test "removed leader's subscription to the Planner stream is rejected" do
    leader = sign_in_as_leader
    project = leader.organization.projects.find(projects(:community_meal).id)
    planner_session = project.planner_sessions.create!(
      started_by: leader,
      description: "Plan a workday",
      flow_version: 3,
      planning_kind: "workday"
    )

    get project_planner_session_path(project, planner_session)
    assert_response :success
    stream_source = css_select("turbo-cable-stream-source").sole
    signed_stream_name = stream_source["signed-stream-name"]
    channel_class = stream_source["channel"].constantize
    session = leader.sessions.order(:id).last
    assert_equal PlannerStreamChannel, channel_class

    subscription = subscribe(channel_class, leader, signed_stream_name)
    assert subscription.confirmed?

    project.memberships.find_by!(person: leader).destroy!

    assert Session.exists?(session.id)
    subscription = subscribe(channel_class, leader, signed_stream_name)

    assert subscription.rejected?
  end

  private
    def subscribe(channel_class, person, signed_stream_name)
      connection = ActionCable::Channel::ConnectionStub.new(current_person: person)
      subscription = channel_class.new(
        connection,
        "planner-stream-revocation-test",
        { signed_stream_name:, planner_session_id: css_select("turbo-cable-stream-source").sole["data-planner-session-id"] }
          .with_indifferent_access
      )
      subscription.singleton_class.include(ActionCable::Channel::ChannelStub)
      subscription.subscribe_to_channel

      subscription
    end
end
