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

  test "an oversized file is rejected before upload" do
    file = Tempfile.new([ "too-large", ".txt" ])
    file.truncate(DocItem::FILE_MAX_BYTES + 1)
    file.close
    sign_in_as_leader_in_browser
    visit project_path(@project)
    click_on "Add File"

    within "dialog.sheet[open]" do
      attach_file "File", file.path
      assert_equal DocItem::FILE_MAX_BYTES.to_s, find("form[data-controller~='upload']")["data-upload-max-bytes-value"]
      assert_equal 0, find_field("File").evaluate_script("this.files.length")
    end

    assert_selector ".tst-viewport [role=alert]", text: "Choose a file 25 MB or smaller", visible: :all
    assert_not @project.doc_items.exists?(title: "Oversized file")
  ensure
    file&.unlink
  end

  private
    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end
end
