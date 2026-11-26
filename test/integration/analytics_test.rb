require "test_helper"

class AnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @client = PostHog::Client.new(api_key: "phc_test", test_mode: true)
    Rails.configuration.x.posthog = @client
  end

  teardown { Rails.configuration.x.posthog = nil }

  test "signing up identifies the new Admin by name and email and records the sign-up" do
    post organizations_path, params: { church_name: "Hope Church", your_name: "Casey Creator", email: "casey@hope.test" }

    creator = Person.find_by!(email: "casey@hope.test")
    identify = messages.find { it[:type] == "identify" }
    assert_equal Analytics.distinct_id(creator), identify[:distinct_id]
    assert_equal({ "role" => "admin", "name" => "Casey Creator", "email" => "casey@hope.test" }, identify[:"$set"].stringify_keys.slice("role", "name", "email"))
    assert_includes events, "Signed up"
    assert_equal({ organization: creator.organization_id.to_s }, messages.find { it[:event] == "Signed up" }[:properties]["$groups"])
  end

  test "a volunteer's changes are tracked with their role and no name or email" do
    volunteer = sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools | [ "signup_sheet" ])
    slot = project.slots.create!(date: "2027-02-15", label: "Bring dessert", capacity: 2)
    @client.clear

    post project_slot_claim_path(project, slot)

    claim = messages.find { it[:event] == "Slot claim created" }
    assert claim, "expected a Slot claim event in #{events}"
    assert_equal Analytics.distinct_id(volunteer), claim[:distinct_id]
    assert_equal "volunteer", claim[:properties]["$set"][:role]
    assert_not claim[:properties]["$set"].key?(:email)
  end

  test "demo visitors are tracked by their browser's PostHog id, not the shared seeded Person" do
    cookies["ph__posthog"] = { distinct_id: "browser-visitor-1" }.to_json
    post demo_session_path(role: "admin")

    sign_in = messages.find { it[:event] == "Signed in" }
    assert_equal "browser-visitor-1", sign_in[:distinct_id]
    assert_not sign_in[:properties]["$set"].key?(:email)
    assert_not messages.any? { it[:type] == "identify" }, "demo visitors stay anonymous so a real sign-up can merge them"
  end

  test "a demo visitor without a PostHog cookie keeps one id across role switches" do
    post demo_session_path(role: "admin")
    post demo_session_path(role: "volunteer")

    ids = messages.select { it[:event] == "Signed in" }.map { it[:distinct_id] }.uniq
    assert_equal 1, ids.size
    assert_not ids.first.start_with?("person_")
  end

  test "sends nothing without an API key" do
    Rails.configuration.x.posthog = nil

    assert_nothing_raised { sign_in_as_volunteer }
  end

  private
    def messages
      @messages ||= Array.new(@client.queued_messages) { @client.dequeue_last_message }
    end

    def events = messages.filter_map { it[:event] }
end
