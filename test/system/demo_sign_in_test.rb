require "application_system_test_case"

class DemoSignInTest < ApplicationSystemTestCase
  test "Explore as Volunteer signs straight in and lands on the Workspace home" do
    visit new_demo_session_path

    click_on "Explore as Volunteer"

    assert_selector "h1", text: "Grace Fellowship"
    assert_text "Signed in as Sam Chen"
  end
end
