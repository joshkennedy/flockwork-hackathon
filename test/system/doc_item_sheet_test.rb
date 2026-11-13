require "application_system_test_case"

class DocItemSheetSystemTest < ApplicationSystemTestCase
  setup do
    @project = Project.create_for(
      creator: people(:grace_leader),
      attributes: {
        name: "Sheet Project",
        description: "Docs to add.",
        starts_on: Date.new(2027, 3, 12),
        ends_on: Date.new(2027, 3, 13),
        enabled_tools: [ "docs" ]
      }
    )
  end

  test "adding a link opens a bottom sheet and stays on the project page" do
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"

    visit project_path(@project)
    click_on "Add Link"

    within "dialog.sheet[open]" do
      assert_selector "h2", text: "Add Link"
      fill_in "Title", with: "Parking map"
      fill_in "URL", with: "https://example.com/parking"
      click_on "Add Link"
    end

    assert_no_selector "dialog.sheet[open]"
    assert_current_path project_path(@project)
    assert_link "Parking map", href: "https://example.com/parking"
  end
end
