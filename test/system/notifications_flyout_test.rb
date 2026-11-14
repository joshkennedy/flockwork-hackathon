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

  test "opening a mention shows its tab, opens the comment thread and scrolls to the comment" do
    person = people(:grace_leader)
    project = Project.create_for(creator: person, attributes: { name: "Mention Project", enabled_tools: [ "messages", "tasks" ] })
    task = project.tasks.create!(title: "Stack the hymnals")
    comment = task.comments.create!(author: people(:grace_volunteer), body: "Can you check this @[Maria Lopez](person:#{person.id})")

    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: person.name
    page.current_window.resize_to(1280, 900)
    visit projects_path

    find(".notifications-menu summary[aria-label='Notifications, 1 unread']").click
    within(".notifications-menu") { find("li[data-notification-id] a").click }

    assert_selector "#tab-tasks:not([hidden])"
    assert_selector "details[open] #comment_#{comment.id}", visible: true
    assert_selector "#comment_#{comment.id} .person-pill", text: "Maria Lopez"
  end
end
