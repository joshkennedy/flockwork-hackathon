require "application_system_test_case"

class ProjectStatusStripSystemTest < ApplicationSystemTestCase
  test "an odd final Project status spans the phone row" do
    project = Project.create_for(
      creator: people(:grace_leader),
      attributes: { name: "Status Strip Project", enabled_tools: [ "signup_sheet" ] }
    )
    project.slots.create!(label: "Welcome", date: Date.current + 1.day, capacity: 2)
    sign_in_as_leader_in_browser
    page.current_window.resize_to(390, 844)

    visit project_path(project)

    strip = find(".status-strip")
    cells = all(".status-strip > div")
    assert_equal 3, cells.size
    strip_width = page.evaluate_script("arguments[0].getBoundingClientRect().width", strip)
    last_width = page.evaluate_script("arguments[0].getBoundingClientRect().width", cells.last)
    assert_in_delta strip_width, last_width, 2
  end

  private
    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end
end
