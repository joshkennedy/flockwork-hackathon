require "application_system_test_case"

class PeopleSlideoutSystemTest < ApplicationSystemTestCase
  test "Add Person validates and saves in the phone slideout" do
    page.current_window.resize_to(390, 844)
    visit new_demo_session_path
    click_on "Explore as Admin"
    assert_selector "[data-signed-in-as]", text: "Daniel Okafor"
    visit people_path

    trigger = find_link("Add Person")
    trigger.click
    within "dialog.slideout[open]" do
      assert_selector "h2", text: "Add Person"
      assert_selector "input[name='person[name]']:focus"
    end

    page.send_keys(:escape)
    assert_no_selector "dialog.slideout[open]"
    assert_equal trigger, page.active_element

    trigger.click
    within "dialog.slideout[open]" do
      click_on "Add Person"
      assert_selector "[role=alert]", text: "Name can't be blank"
      fill_in "Name", with: "Phone Slideout Person"
      fill_in "Email", with: "phone-slideout@example.test"
      click_on "Add Person"
    end

    assert_no_selector "dialog.slideout[open]"
    assert_current_path people_path
    assert_text "Phone Slideout Person"
  end
end
