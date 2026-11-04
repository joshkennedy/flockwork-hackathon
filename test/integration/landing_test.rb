require "test_helper"

class LandingTest < ActionDispatch::IntegrationTest
  test "landing explains typed and voice planner privacy" do
    get root_path
    assert_response :success
    assert_select "p", text: /Typed planning uses Project details, not your people directory/
    assert_select "p", text: /speech service/
  end

  test "public landing links to separate signup, sign in and demo" do
    get root_path
    assert_response :success
    assert_select "h1", "Ministry,together."
    assert_select "a[href=?]", sign_up_path
    assert_select "a[href=?]", new_sign_in_request_path
    assert_select "a[href=?]", new_demo_session_path
    assert_select "form", count: 0
    get sign_up_path
    assert_response :success
    assert_select "form[action=?]", organizations_path
  end

  test "signed in visitors go to their home" do
    sign_in_as_leader
    get root_path
    assert_redirected_to home_path
    get sign_up_path
    assert_redirected_to home_path
  end

  test "invalid sign in link offers a direct retry" do
    get sign_in_link_path("invalid")
    assert_response :unprocessable_content
    assert_select "a[href=?]", new_sign_in_request_path, text: "Request a New Sign-In Link"
  end
end
