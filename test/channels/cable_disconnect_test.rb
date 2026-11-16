require "test_helper"

class CableDisconnectTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  DISCONNECT = { "type" => "disconnect", "reconnect" => true }.freeze

  test "logout closes that Session's cable connections" do
    sign_in_as_leader
    session = Session.order(:id).last

    messages = capture_broadcasts("action_cable/#{session.to_gid_param}") { delete session_path }

    assert_equal [ DISCONNECT ], messages
  end

  test "logout leaves the person's other Sessions' cable connections open" do
    leader = sign_in_as_leader
    other = leader.sessions.create!(auth_method: "email_link", user_agent: "Other", ip_address: "127.0.0.2")

    messages = capture_broadcasts("action_cable/#{other.to_gid_param}") { delete session_path }

    assert_empty messages
  end

  test "removing a member closes their cable connections so project streams resubscribe through Policy" do
    volunteer = people(:volunteer)
    volunteer_session = volunteer.sessions.create!(auth_method: "email_link", user_agent: "Phone", ip_address: "127.0.0.3")
    sign_in_as_leader

    messages = capture_broadcasts("action_cable/#{volunteer_session.to_gid_param}") do
      delete project_membership_path(projects(:community_meal), memberships(:community_meal_volunteer))
    end

    assert_equal [ DISCONNECT ], messages
    assert Session.exists?(volunteer_session.id)
  end

  test "removing a member replaces their open Project page with an access message" do
    project = projects(:community_meal)
    volunteer = people(:volunteer)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ project, volunteer ])
    sign_in_as_leader

    messages = capture_broadcasts(stream) do
      delete project_membership_path(project, memberships(:community_meal_volunteer))
    end

    assert_equal 1, messages.size
    assert_includes messages.first, %(action="replace" target="project-membership-access")
    assert_includes messages.first, "You no longer have access to Community Meal."
  end

  test "signing in again from the same browser invalidates that browser's previous Session" do
    leader = sign_in_as_leader
    old_session = leader.sessions.order(:id).last
    old_cookie = cookies[:session_id]

    messages = capture_broadcasts("action_cable/#{old_session.to_gid_param}") { sign_in_as_leader }

    assert_equal [ DISCONNECT ], messages
    assert_not Session.exists?(old_session.id)
    cookies[:session_id] = old_cookie
    get home_path
    assert_redirected_to root_path
  end
end
