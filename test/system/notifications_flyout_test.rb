require "application_system_test_case"

class NotificationsFlyoutTest < ApplicationSystemTestCase
  test "the bell opens Notifications in place and marking read keeps the flyout open on the same page" do
    person = people(:grace_leader)
    project = Project.create_for(creator: person, attributes: { name: "Flyout Project", enabled_tools: [] })
    slot = project.slots.create!(date: "2027-02-11", label: "Bring dessert")
    slot.slot_claims.create!(person: person)
    Notifier.notify(recipient: person, kind: "slot_reminder", notifiable: slot, email: false)

    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: person.name
    page.current_window.resize_to(1280, 900)
    visit projects_path

    find(".notifications-menu summary[aria-label='Notifications, 1 unread']").click
    within ".notifications-menu" do
      assert_selector "li[data-notification-id]", count: 1
      click_on "Mark All Read"
      assert_no_button "Mark All Read"
      assert_selector "li[data-notification-id]", count: 1
    end
    assert_selector ".notifications-menu[open]"
    assert_current_path projects_path
  end
end
