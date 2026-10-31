require "test_helper"

class DemoSignInTest < ActionDispatch::IntegrationTest
  test "the demo page offers the three role buttons" do
    get new_demo_session_path

    assert_response :success
    assert_select "button", text: "Explore as Admin", count: 1
    assert_select "button", text: "Explore as Leader", count: 1
    assert_select "button", text: "Explore as Volunteer", count: 1
  end

  test "the sign-in page links to the demo" do
    get new_sign_in_request_path

    assert_select "a[href=?]", new_demo_session_path
  end

  test "Explore as Admin signs in as the demo Admin" do
    post demo_session_path(role: "admin")

    assert_redirected_to home_path
    follow_redirect!
    assert_select "p", "Signed in as Daniel Okafor"
  end

  test "Explore as Leader signs in as the demo Leader" do
    post demo_session_path(role: "leader")

    assert_redirected_to home_path
    follow_redirect!
    assert_select "p", "Signed in as Maria Lopez"
  end

  test "Explore as Volunteer signs in as the demo Volunteer" do
    post demo_session_path(role: "volunteer")

    assert_redirected_to home_path
    follow_redirect!
    assert_select "p", "Signed in as Sam Chen"
  end

  test "the demo endpoint 404s when the demo Workspace is not flagged demo, and starts no session" do
    workspaces(:grace_fellowship).update!(demo: false)

    post demo_session_path(role: "admin")

    assert_response :not_found
    get home_path
    assert_redirected_to root_path
  end

  test "an unknown role 404s" do
    post demo_session_path(role: "pastor")

    assert_response :not_found
  end
end
