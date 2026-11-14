require "application_system_test_case"

class DemoSignInSystemTest < ApplicationSystemTestCase
  test "Explore as Volunteer signs straight in and lands on the Organization home" do
    visit new_demo_session_path

    click_on "Explore as Volunteer"

    assert_selector "[data-organization-name]", text: "Grace Fellowship"
    assert_selector "[data-signed-in-as]", text: "Sam Chen"
  end
end
