require "application_system_test_case"

class ToastsSystemTest < ApplicationSystemTestCase
  test "Ding survives Turbo visits and announces later notices through the same live region" do
    visit new_demo_session_path
    click_on "Explore as Leader"

    find(".account-menu summary", match: :first).click
    click_on "Settings"
    click_on "Save Changes", match: :first

    assert_selector ".tst-viewport [role=status]", text: "Settings saved.", visible: :all
    page.execute_script("document.querySelector('.tst-viewport').dataset.systemTest = 'same-root'")

    find(".account-menu summary", match: :first).click
    click_on "Settings"
    assert_selector ".tst-viewport[data-system-test=same-root]", count: 1, visible: :all
    click_on "Save Changes", match: :first

    assert_selector ".tst-viewport [role=status]", text: "Settings saved.", visible: :all
    assert_selector ".tst-viewport", count: 1, visible: :all
  end

  test "a check-in toast can undo the check-in" do
    visit new_demo_session_path
    click_on "Explore as Admin"
    assert_selector "[data-signed-in-as]", text: "Daniel Okafor"
    person = people(:grace_volunteer)

    visit person_path(person)
    assert_difference "CheckIn.count", 1 do
      click_on "Log a Check-In"
      assert_selector ".tst-action", text: "Undo"
    end

    assert_difference "CheckIn.count", -1 do
      find(".tst-action", text: "Undo").click
      assert_text "Undid the check-in with Sam Chen."
    end
  end
end
