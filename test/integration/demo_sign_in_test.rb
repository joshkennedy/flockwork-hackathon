require "test_helper"

class DemoSignInTest < ActionDispatch::IntegrationTest
  test "the demo sign-in page offers the three role buttons" do
    get new_sign_in_request_path(workspaces(:grace_fellowship))

    assert_response :success
    assert_select "button", text: "Explore as Admin", count: 1
    assert_select "button", text: "Explore as Leader", count: 1
    assert_select "button", text: "Explore as Volunteer", count: 1
  end

  test "Explore as Admin signs in as the demo Admin" do
    post demo_session_path("grace-fellowship", role: "admin")

    assert_redirected_to "/grace-fellowship"
    follow_redirect!
    assert_select "p", "Signed in as Daniel Okafor"
  end

  test "Explore as Leader signs in as the demo Leader" do
    post demo_session_path("grace-fellowship", role: "leader")

    assert_redirected_to "/grace-fellowship"
    follow_redirect!
    assert_select "p", "Signed in as Maria Lopez"
  end

  test "Explore as Volunteer signs in as the demo Volunteer" do
    post demo_session_path("grace-fellowship", role: "volunteer")

    assert_redirected_to "/grace-fellowship"
    follow_redirect!
    assert_select "p", "Signed in as Sam Chen"
  end

  test "a non-demo Workspace's sign-in page shows no role buttons" do
    get new_sign_in_request_path(workspaces(:st_example))

    assert_response :success
    assert_select "button", text: "Explore as Admin", count: 0
  end

  test "the demo sign-in endpoint 404s for a non-demo Workspace and starts no session" do
    post demo_session_path("st-example", role: "admin")

    assert_response :not_found
    get workspace_path("st-example")
    assert_redirected_to root_path
  end

  test "an unknown role 404s" do
    post demo_session_path("grace-fellowship", role: "pastor")

    assert_response :not_found
  end
end
