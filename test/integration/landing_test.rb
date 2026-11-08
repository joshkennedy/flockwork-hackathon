require "test_helper"

class LandingTest < ActionDispatch::IntegrationTest
  test "landing opens with the category headline and both calls to action" do
    get root_path
    assert_response :success
    assert_select "title", "Flockwork · Project planning for your church"
    assert_select "h1", "Project planning for your church."
    assert_select ".lp-hero a.btn-primary[href=?]", sign_up_path, text: "Plan Your First Project"
    assert_select ".lp-hero a.btn-secondary[href=?]", new_demo_session_path, text: "See It With Real Data"
    assert_select ".lp-hero", text: /say yes to more of them/
    assert_select ".lp-hero", text: /Free to start/, count: 0
    assert_select "form", count: 0
  end

  test "landing footer carries the tagline and the public links" do
    get root_path
    assert_select ".public-footer span", "Project planning for your church."
    assert_select ".public-footer a[href=?]", new_sign_in_request_path, text: "Sign In"
    assert_select ".public-footer a[href=?]", new_demo_session_path, text: "See the Demo"
  end

  test "sign up page posts to organizations" do
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
