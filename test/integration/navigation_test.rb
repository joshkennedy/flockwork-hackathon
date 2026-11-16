require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "a Volunteer's nav has no People, Oversight or Settings, and Profile is in the account menu" do
    sign_in_as_volunteer
    get home_path

    assert_select "nav[aria-label='Main navigation'] a[href='#{home_path}']"
    assert_select "a[href='#{people_path}']", count: 0
    assert_select "a[href='#{oversight_path}']", count: 0
    assert_select "nav[aria-label='Main navigation'] a[href^='#{settings_path}']", count: 0
    assert_select "details.account-menu a[href='#{profile_path}']", text: /Profile/, count: 1
    assert_select "details.account-menu a[href='#{settings_path}']", text: /Settings/, count: 1
    assert_select "details.manage-menu", count: 0
  end

  test "an Admin gets People on the phone tab bar while desktop keeps it under Manage" do
    sign_in_as_admin
    get home_path

    assert_select "nav.fixed[aria-label='Main navigation'] > a.app-tab[href='#{people_path}']", count: 1
    assert_select "nav.fixed[aria-label='Main navigation'] > details.manage-menu a[href='#{people_path}']", count: 0
    assert_select "nav.fixed[aria-label='Main navigation'] > details.manage-menu a[href='#{oversight_path}']", count: 1
    assert_select "nav.fixed[aria-label='Main navigation'] > details.manage-menu a[href='#{settings_path(anchor: "settings-church")}']", count: 1
    assert_select "nav.hidden[aria-label='Main navigation'] details.manage-menu a[href='#{people_path}']", count: 1
    assert_select "details.account-menu a[href='#{settings_path}']", count: 1
  end

  test "a Leader, allowed only Oversight, gets it as a plain destination with no Manage menu" do
    sign_in_as_leader
    get home_path

    assert_select "details.manage-menu", count: 0
    assert_select "nav[aria-label='Main navigation'] a.nav-pill[href='#{oversight_path}']", "Oversight"
    assert_select "nav[aria-label='Main navigation'] a.app-tab[href='#{oversight_path}']"
  end

  test "the account menu offers Switch church only when the Person belongs to several Organizations" do
    sign_in_as_leader
    get home_path
    assert_select "a[href='#{new_organization_choice_path}']", count: 0

    organizations(:outsider_church).people.create!(name: "Leo Elsewhere", email: "leo@st-example.test")
    get home_path

    assert_select "details.account-menu a[href='#{new_organization_choice_path}']", text: /Switch Church/, count: 1
  end

  test "the bell carries the unread count and opens Notifications as a flyout, except on the Notifications page" do
    person = sign_in_as_volunteer
    slot = projects(:community_meal).slots.create!(date: "2027-02-11", label: "Bring dessert")
    slot.slot_claims.create!(person: person)
    Notifier.notify(recipient: person, kind: "slot_reminder", notifiable: slot, email: false)
    get home_path

    assert_select "header details.notifications-menu summary[aria-label='Notifications, 1 unread'] span[aria-hidden='true']", "1"
    assert_select "header details.notifications-menu turbo-frame#notifications[src='#{notifications_path}'][loading='lazy']"

    get notifications_path

    assert_select "header details.notifications-menu", count: 0
    assert_select "header a[href='#{notifications_path}'][aria-current='page']"
  end
end
