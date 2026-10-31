require "test_helper"

class WorkspaceScopingTest < ActionDispatch::IntegrationTest
  test "the home page shows only the signed-in Person's own Workspace" do
    sign_in_as_volunteer

    get home_path

    assert_select "h1", "St. Example"
    assert_select "p", "Signed in as Vic Volunteer"
    assert_no_match "Outsider Church", response.body
  end

  test "the outsider's home shows only the outsider's Workspace" do
    sign_in_as_outsider

    get home_path

    assert_select "h1", "Outsider Church"
    assert_no_match "St. Example", response.body
  end

  test "the home page redirects to the landing page when signed out" do
    get home_path

    assert_redirected_to root_path
  end

  test "the landing page sends a signed-in Person to their home" do
    sign_in_as_admin

    get root_path

    assert_redirected_to home_path
  end

  test "the landing page links to sign-in and the demo" do
    get root_path

    assert_select "a[href=?]", new_sign_in_request_path, text: "Sign in"
    assert_select "a[href=?]", new_demo_session_path, text: "explore the demo"
  end
end
