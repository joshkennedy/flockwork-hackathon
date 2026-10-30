require "test_helper"

class WorkspaceScopingTest < ActionDispatch::IntegrationTest
  test "the home page shows only the signed-in Person's own Workspace" do
    sign_in_as_volunteer

    get workspace_path("outsider-church")

    assert_redirected_to "/st-example"
    follow_redirect!
    assert_select "h1", "St. Example"
    assert_select "p", "Signed in as Vic Volunteer"
    assert_no_match "Outsider Church", response.body
  end

  test "the outsider's home shows only the outsider's Workspace" do
    sign_in_as_outsider

    get workspace_path("st-example")

    assert_redirected_to "/outsider-church"
  end

  test "the Workspace home redirects to the landing page when signed out" do
    get workspace_path("st-example")

    assert_redirected_to root_path
  end

  test "the landing page sends a signed-in Person to their Workspace home" do
    sign_in_as_admin

    get root_path

    assert_redirected_to "/st-example"
  end
end
