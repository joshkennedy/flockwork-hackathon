require "test_helper"

class DigestPreferencesTest < ActionDispatch::IntegrationTest
  test "weekly preferences require sign-in" do
    patch profile_path, params: { person: { email_preferences: { weekly_project_digest: "0" } } }
    assert_response :redirect
    assert_empty people(:leader).reload.email_preferences
  end

  test "a Leader can opt out and back in from Notifications without changing other preferences or another person" do
    person = people(:leader)
    person.update!(email_preferences: { "mention" => false })
    sign_in_as_leader

    get settings_path
    assert_select "#settings-notifications input[type=checkbox][name='person[email_preferences][weekly_project_digest]'][checked]"
    patch profile_path, params: { tab: "notifications", person_id: people(:other_leader).id, person: { email_preferences: { weekly_project_digest: "0" } } }
    assert_redirected_to settings_path(anchor: "settings-notifications")
    assert_equal({ "mention" => false, "weekly_project_digest" => false }, person.reload.email_preferences)
    assert_empty people(:other_leader).reload.email_preferences

    patch profile_path, params: { person: { email_preferences: { weekly_project_digest: "1" } } }
    assert_equal({ "mention" => false, "weekly_project_digest" => true }, person.reload.email_preferences)
  end

  test "Volunteers who lead nothing are not offered the weekly Project email" do
    sign_in_as_volunteer

    get settings_path

    assert_select "input[name='person[email_preferences][weekly_project_digest]']", count: 0
  end
end
