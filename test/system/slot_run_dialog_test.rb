require "application_system_test_case"

class SlotRunDialogSystemTest < ApplicationSystemTestCase
  setup do
    @project = Project.create_for(
      creator: people(:grace_leader),
      attributes: { name: "Bulk Slots", enabled_tools: [ "signup_sheet" ] }
    )
  end

  test "a reversed date range keeps the Project and error inside the modal" do
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(@project)
    find("summary[aria-label='Actions for Sign-up sheet']").click
    click_on "Add Multiple Slots"

    within "dialog.modal[open]" do
      fill_in "Start date", with: "2027-02-20"
      fill_in "End date", with: "2027-02-19"
      fill_in "Label", with: "Serve dinner"
      fill_in "Capacity", with: "2"
      click_on "Add Slots"
    end

    assert_selector "dialog.modal[open] [role=alert]", text: "End date must be on or after the start date"
    assert_current_path project_path(@project)
    assert_text "Bulk Slots"
  end
end
