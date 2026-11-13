require "test_helper"

class SignInChallengeJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @organization = organizations(:st_example)
    @project = projects(:community_meal)
    @previous_key = ENV["SENDLY_API_KEY"]
    ENV["SENDLY_API_KEY"] = "sandbox"
    @sms = stub_request(:post, "https://sendly.live/api/v1/messages").to_return(status: 201, body: { id: "msg_test", status: "queued" }.to_json)
  end

  teardown do
    @previous_key.nil? ? ENV.delete("SENDLY_API_KEY") : ENV["SENDLY_API_KEY"] = @previous_key
  end

  test "the current challenge gets its code" do
    assert_emails(1) { SignInChallengeJob.perform_now(issue("nadia@example.com")) }
  end

  test "a challenge replaced by a newer one sends nothing" do
    first = issue("nadia@example.com")
    issue("nadia@example.com")

    assert_no_emails { SignInChallengeJob.perform_now(first) }
    assert_nil first.reload.code_digest
  end

  test "a challenge that expired before the job ran sends nothing" do
    challenge = issue("nadia@example.com")

    travel SignInChallenge::LIFETIME + 1.minute do
      assert_no_emails { SignInChallengeJob.perform_now(challenge) }
    end
  end

  test "a number that sent STOP after asking for a code gets no text" do
    challenge = issue("+12025550177", channel: "sms")
    SmsOptOut.opt_out!("+12025550177", at: Time.current)

    SignInChallengeJob.perform_now(challenge)

    assert_not_requested @sms
  end

  private
    def issue(address, channel: "email")
      SignInChallenge.issue(organization: @organization, project: @project, channel:, address:)
    end
end
