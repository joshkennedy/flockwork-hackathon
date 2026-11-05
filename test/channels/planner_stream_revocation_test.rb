require "test_helper"
require "action_cable/channel/test_case"

class PlannerStreamRevocationTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  module DeliveryChannelStub
    include ActionCable::Channel::ChannelStub

    def stream_from(broadcasting, callback = nil, coder: nil, &block)
      streams << broadcasting
      @delivery_callback = callback || block
      @delivery_coder = coder
    end

    def deliver(message)
      encoded = ActiveSupport::JSON.encode(message)
      if @delivery_callback
        @delivery_callback.call(@delivery_coder ? @delivery_coder.decode(encoded) : encoded)
      else
        transmit(ActiveSupport::JSON.decode(encoded))
      end
    end
  end

  test "stock Turbo stream cannot receive Planner updates" do
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
    signed_stream_name = css_select("turbo-cable-stream-source").sole["signed-stream-name"]
    subscription = subscribe(Turbo::StreamsChannel, leader, signed_stream_name, live: true)
    assert wait_until { subscription.send(:subscription_confirmation_sent?) }
    stream_name = Turbo::StreamsChannel.verified_stream_name(signed_stream_name)
    assert subscription.send(:streams).key?(stream_name)
    handler = subscription.send(:default_stream_handler, stream_name, coder: nil)
    transmission_count = subscription.connection.transmissions.size

    unauthorized_messages = capture_broadcasts(stream_name) do
      Planner::PreviewStream.new(planner_session, clock: -> { 0.0 }).push(
        card: { "question" => "Which work?", "options" => %w[Cleanup Repairs Setup] },
        added: []
      )
    end
    assert_equal 1, broadcasts(PlannerStreamChannel.authorized_stream_name(planner_session)).size
    unauthorized_messages.each { |message| handler.call(ActiveSupport::JSON.encode(message)) }

    assert_not wait_until { subscription.connection.transmissions.size > transmission_count }
  end

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

  test "existing Planner subscription stops delivery after leader removal" do
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
    signed_stream_name = css_select("turbo-cable-stream-source").sole["signed-stream-name"]
    subscription = subscribe(PlannerStreamChannel, leader, signed_stream_name, delivery: true)
    assert subscription.confirmed?
    stream_name = PlannerStreamChannel.authorized_stream_name(planner_session)
    authorized_messages = capture_broadcasts(stream_name) do
      Planner::PreviewStream.new(planner_session, clock: -> { 0.0 }).push(
        card: { "question" => "Which work?", "options" => %w[Cleanup Repairs Setup] },
        added: []
      )
    end
    assert_equal 1, authorized_messages.size
    authorized_messages.each { |message| subscription.deliver(message) }
    assert_equal authorized_messages.sole, subscription.connection.transmissions.last["message"]
    transmission_count = subscription.connection.transmissions.size

    project.memberships.find_by!(person: leader).destroy!
    messages = capture_broadcasts(stream_name) do
      Planner::PreviewStream.new(planner_session, clock: -> { 0.0 }).push(
        card: { "question" => "Which work?", "options" => %w[Cleanup Repairs Setup] },
        added: []
      )
    end
    assert_equal 1, messages.size
    messages.each { |message| subscription.deliver(message) }

    assert_equal transmission_count, subscription.connection.transmissions.size
  end

  private
    def subscribe(channel_class, person, signed_stream_name, live: false, delivery: false)
      connection = ActionCable::Channel::ConnectionStub.new(current_person: person)
      subscription = channel_class.new(
        connection,
        "planner-stream-revocation-test",
        { signed_stream_name:, planner_session_id: css_select("turbo-cable-stream-source").sole["data-planner-session-id"] }
          .with_indifferent_access
      )
      subscription.singleton_class.include(delivery ? DeliveryChannelStub : ActionCable::Channel::ChannelStub) unless live
      subscription.subscribe_to_channel

      subscription
    end

    def wait_until(timeout: 1)
      Timeout.timeout(timeout) do
        sleep 0.001 until yield
        true
      end
    rescue Timeout::Error
      false
    end
end
