require "test_helper"

class DemoNoticeTest < ActionDispatch::IntegrationTest
  test "demo signed-in and Public pages show the reset countdown" do
    travel_to Time.zone.local(2026, 11, 13, 12, 42) do
      organization = DemoOrganization.seed!

      post demo_session_path(role: "volunteer")
      follow_redirect!
      assert_select "[data-demo-notice]", "Demo church. Everything resets in 18 minutes."

      project = organization.projects.find_by!(name: "Meal Train for the Alvarez Family")
      project.enable_public_link!
      get public_project_path(project.public_token)
      assert_select "[data-demo-notice]", "Demo church. Everything resets in 18 minutes."
    end
  end

  test "real church signed-in and Public pages do not show the reset countdown" do
    sign_in_as_volunteer
    get home_path
    assert_select "[data-demo-notice]", count: 0

    project = projects(:community_meal)
    project.enable_public_link!
    get public_project_path(project.public_token)
    assert_select "[data-demo-notice]", count: 0
  end

  test "the role picker explains the hourly reset" do
    get new_demo_session_path

    assert_response :success
    assert_select "p.text-meta", "This demo resets every hour, on the hour. Anything you add is cleared then."
  end

  test "the final minute uses calm singular countdown copy" do
    travel_to Time.zone.local(2026, 11, 13, 12, 59, 0) do
      organization = DemoOrganization.seed!
      project = organization.projects.find_by!(name: "Meal Train for the Alvarez Family")
      project.enable_public_link!

      get public_project_path(project.public_token)
      assert_select "[data-demo-notice]", "Demo church. Everything resets in 1 minute."
    end

    travel_to Time.zone.local(2026, 11, 13, 12, 59, 30) do
      project = Organization.find_by!(slug: DemoOrganization::SLUG).projects.find_by!(name: "Meal Train for the Alvarez Family")

      get public_project_path(project.public_token)
      assert_select "[data-demo-notice]", "Demo church. Everything resets in less than a minute."
    end
  end
end
