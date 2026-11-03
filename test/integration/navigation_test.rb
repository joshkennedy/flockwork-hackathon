require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "a Volunteer's nav has no People, Oversight or Settings, and Profile is in the account menu" do
    sign_in_as_volunteer
    get home_path

    assert_select "nav[aria-label='Main navigation'] a[href='#{home_path}']"
    assert_select "a[href='#{people_path}']", count: 0
    assert_select "a[href='#{oversight_path}']", count: 0
    assert_select "a[href='#{settings_path}']", count: 0
    assert_select "details.account-menu a[href='#{edit_profile_path}']", text: /Profile/, count: 2
  end

  test "an Admin sees Settings in the account menu, not the main nav" do
    sign_in_as_admin
    get home_path

    assert_select "nav[aria-label='Main navigation'] a[href='#{settings_path}']", count: 0
    assert_select "details.account-menu a[href='#{settings_path}']", text: /Settings/, count: 2
  end

  test "the account menu offers Switch church only when the Person belongs to several Organizations" do
    sign_in_as_leader
    get home_path
    assert_select "a[href='#{new_organization_choice_path}']", count: 0

    organizations(:outsider_church).people.create!(name: "Leo Elsewhere", email: "leo@st-example.test")
    get home_path

    assert_select "details.account-menu a[href='#{new_organization_choice_path}']", text: /Switch Church/, count: 2
  end

  test "the phone bell carries the unread count in its label" do
    person = sign_in_as_volunteer
    slot = projects(:community_meal).slots.create!(date: "2027-02-11", label: "Bring dessert")
    slot.slot_claims.create!(person: person)
    Notifier.notify(recipient: person, kind: "slot_reminder", notifiable: slot, email: false)
    get home_path

    assert_select "header a[href='#{notifications_path}'][aria-label='Notifications, 1 unread']"
    assert_select "header a[href='#{notifications_path}'] span[aria-hidden='true']", "1"
  end
end
