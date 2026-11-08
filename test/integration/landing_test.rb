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

  test "landing has no tabbed tour and no numbered steps" do
    get root_path
    assert_select "[data-controller=product-tour]", count: 0
    assert_select ".lp-steps", count: 0
  end

  test "landing places Flockwork between the roster and the day" do
    get root_path
    assert_select ".lp-between h2", "Everything between the idea and the day."
    assert_select ".lp-between .lp-track-end", count: 2
    assert_select ".lp-between .lp-track-end", text: /Planning Center, Breeze, or whatever you use/
    assert_select ".lp-between .lp-track-step", count: 4
    assert_select ".lp-between .lp-track-step", text: "Send one link"
    assert_select ".lp-between .lp-track-card h3", "The planning"
    assert_select ".lp-between .lp-intro p", "Planning Center knows who’s in your church. It’ll check them in when they arrive. The weeks of planning in between have been running on email, a spreadsheet and a group text. That’s the part Flockwork takes."
    assert_select ".lp-between .lp-track-card p", /Who’s bringing what\..*What it’s costing\./
    assert_select ".lp-between", text: /nobody types a roster twice/
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

  test "landing shows all four project tools without a click" do
    get root_path
    assert_select ".lp-tour h2", "One project holds the whole thing."
    assert_select ".lp-tour .lp-rail-item", count: 4
    assert_select ".lp-rail button[type=button]", count: 4
    assert_select ".lp-tour .lp-tour-screen", count: 4
    assert_select ".lp-tour .lp-tour-screen[hidden]", count: 0
    %w[tour-signup tour-tasks tour-schedule tour-budget].each do |name|
      assert_select ".lp-tour img[src*=?]", "marketing/#{name}"
    end
    assert_select ".lp-tour .lp-tour-screen h3", "Spots that fill themselves"
    assert_select ".lp-tour .lp-tour-screen h3", "A budget you can actually see"
  end

  test "landing introduces the planner as the way in" do
    get root_path
    assert_select ".lp-planner h2", "Start with one sentence."
    assert_select ".lp-planner p", text: /never sees your people directory/
    assert_select ".lp-planner img[src*=?]", "marketing/tour-planner"
  end

  test "landing reframes the people cards and explains why it exists" do
    get root_path
    assert_select ".lp-bento h3", "One link, from any phone"
    assert_select ".lp-bento h3", "Notice who’s carrying too much"
    assert_select ".lp-why h2", "Built up in love."
    assert_select ".lp-why", text: /Ephesians 4:15–16/
    assert_select ".lp-why", text: /says yes more often/
    assert_select ".lp-close h2", "Say yes to the next one."
    assert_select ".lp-close a.btn-primary[href=?]", sign_up_path, text: "Plan Your First Project"
  end

  test "landing tells the story in the spec's order" do
    get root_path
    ids = css_select("section[aria-labelledby]").map { |section| section["aria-labelledby"] }
    assert_equal %w[landing-title between-title planner-title tour-title people-title why-title close-title], ids
  end
end
