require "test_helper"

class DigestPreferencesTest < ActionDispatch::IntegrationTest
  test "weekly preferences require sign-in" do
    get digest_preferences_path
    assert_response :redirect
    patch digest_preferences_path, params: { digest: { enabled: "0" } }
    assert_response :redirect
    assert_empty people(:leader).reload.email_preferences
  end

  test "a Leader can opt out and back in without changing other preferences or another person" do
    person = people(:leader)
    person.update!(email_preferences: { "mention" => false })
    sign_in_as_leader

    get digest_preferences_path
    assert_response :success
    patch digest_preferences_path, params: { person_id: people(:other_leader).id, digest: { enabled: "0" } }
    assert_redirected_to digest_preferences_path
    assert_equal({ "mention" => false, "weekly_project_digest" => false }, person.reload.email_preferences)
    assert_empty people(:other_leader).reload.email_preferences

    patch digest_preferences_path, params: { digest: { enabled: "1" } }
    assert_equal({ "mention" => false, "weekly_project_digest" => true }, person.reload.email_preferences)
  end
end
