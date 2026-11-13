require "application_system_test_case"

class NotificationPreferencesTest < ApplicationSystemTestCase
  test "a person saves mixed channel preferences and can turn every channel off on mobile" do
    person = people(:grace_volunteer)
    visit new_demo_session_path
    click_on "Explore as Volunteer"
    assert_selector "[data-signed-in-as]", text: person.name

    page.current_window.resize_to(1280, 900)
    visit settings_path
    find("a[data-tabs-name=notifications]").click
    assert_text "Notification delivery"
    assert_selector "#person_in_app_preferences_invitation:checked"
    assert_no_selector "#person_sms_preferences_invitation:checked"
    page.save_screenshot(Rails.root.join("tmp/notification-preferences-desktop.png"))

    click_on "Change phone"
    fill_in "Phone", with: "+1 (500) 555-0000"
    find("a[data-tabs-name=notifications]").click
    uncheck "Invitations via in-app"
    uncheck "Invitations via EMAIL"
    check "Invitations via SMS"
    click_button "Save Changes"
    assert_text "Settings saved."
    assert person.reload.notification_for?("sms", "invitation")
    assert_not person.notification_for?("email", "invitation")
    assert_not person.notification_for?("in_app", "invitation")
    assert_equal "+15005550000", person.phone

    page.current_window.resize_to(390, 844)
    visit settings_path
    find("a[data-tabs-name=notifications]").click
    assert_selector "#person_sms_preferences_invitation:checked"
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
    page.save_screenshot(Rails.root.join("tmp/notification-preferences-mobile.png"))
    within "#settings-notifications" do
      all("input[type=checkbox]").each(&:check)
      assert_selector "input[type=checkbox]:checked", count: 18
      all("input[type=checkbox]").each(&:uncheck)
      click_button "Save Changes"
    end
    assert_text "Settings saved."

    person.reload
    Notification::KINDS.each_key do |kind|
      Person::NOTIFICATION_CHANNELS.each_key { |channel| assert_not person.notification_for?(channel, kind) }
    end
  end

  test "SMS validation keeps the form and explains how to fix the phone number" do
    visit new_demo_session_path
    click_on "Explore as Volunteer"
    assert_selector "[data-signed-in-as]", text: "Sam Chen"
    visit settings_path
    find("a[data-tabs-name=notifications]").click
    check "Invitations via SMS"
    click_button "Save Changes"

    assert_selector "[role=alert]", text: "country code"
    click_on "Change phone"
    fill_in "Phone", with: "+15005550000"
    find("a[data-tabs-name=notifications]").click
    click_button "Save Changes"
    assert_text "Settings saved."
    assert people(:grace_volunteer).reload.notification_for?("sms", "invitation")
  end
end
