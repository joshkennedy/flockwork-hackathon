require "test_helper"

class SendlyWebhookTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @previous = ENV.to_h.slice("SENDLY_WEBHOOK_SECRET", "SENDLY_API_KEY")
    ENV["SENDLY_WEBHOOK_SECRET"] = "whsec_test"
    ENV["SENDLY_API_KEY"] = "sandbox"
    @volunteer = people(:volunteer)
    @volunteer.update!(phone: "+15005550000", sms_preferences: { task_assigned: true, invitation: false })
    @leader = people(:leader)
    @leader.update!(phone: "+15005550000", sms_preferences: { invitation: true })
  end

  teardown do
    %w[SENDLY_WEBHOOK_SECRET SENDLY_API_KEY].each { |key| @previous.key?(key) ? ENV[key] = @previous[key] : ENV.delete(key) }
  end

  test "opt out disables SMS for every person with the phone and the job refuses the number" do
    post_event("evt_1", "message.opt_out", "+1 (500) 555-0000")

    assert_response :ok
    assert_not @volunteer.reload.notification_for?("sms", "task_assigned")
    assert_not @leader.reload.notification_for?("sms", "invitation")

    @volunteer.update!(sms_preferences: { task_assigned: true })
    task = projects(:community_meal).tasks.create!(title: "Set out chairs", assignee: @volunteer)
    notification = Notifier.notify(recipient: @volunteer, kind: "task_assigned", notifiable: task, actor: @leader)
    SmsNotificationJob.perform_now(notification.id)

    assert_equal "cancelled", notification.reload.sms_status
    assert_empty notification.sms_payload
  end

  test "opt in restores only the preferences the opt out disabled" do
    post_event("evt_1", "message.opt_out", "+15005550000")
    @volunteer.update!(sms_preferences: @volunteer.sms_preferences.merge("mention" => false))
    post_event("evt_2", "message.opt_in", "+15005550000")

    assert_response :ok
    assert @volunteer.reload.notification_for?("sms", "task_assigned")
    assert_not @volunteer.notification_for?("sms", "invitation")
    assert_not @volunteer.notification_for?("sms", "mention")
    assert @leader.reload.notification_for?("sms", "invitation")
    assert_not SmsOptOut.blocked?("+15005550000")
  end

  test "bad signature, stale timestamp and missing secret return 401 and change nothing" do
    post_event("evt_1", "message.opt_out", "+15005550000", signature: "sha256=bad")
    assert_response :unauthorized
    post_event("evt_2", "message.opt_out", "+15005550000", timestamp: 10.minutes.ago.to_i)
    assert_response :unauthorized
    ENV.delete("SENDLY_WEBHOOK_SECRET")
    post_event("evt_3", "message.opt_out", "+15005550000", secret: "")
    assert_response :unauthorized

    assert @volunteer.reload.notification_for?("sms", "task_assigned")
    assert_equal 0, SmsOptOut.count
    assert_equal 0, SmsWebhookEvent.count
  end

  test "a replayed event id is a no-op" do
    post_event("evt_1", "message.opt_out", "+15005550000")
    post_event("evt_2", "message.opt_in", "+15005550000")
    @volunteer.update!(sms_preferences: { task_assigned: false })
    post_event("evt_1", "message.opt_out", "+15005550000")

    assert_response :ok
    assert_not SmsOptOut.blocked?("+15005550000")
    assert_not @volunteer.reload.notification_for?("sms", "task_assigned")
  end

  private
    def post_event(id, type, phone, timestamp: Time.current.to_i, signature: nil, secret: "whsec_test")
      body = { id:, type:, data: { from: phone } }.to_json
      signature ||= "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")}"
      post "/webhooks/sendly", params: body,
        headers: { "Content-Type" => "application/json", "X-Sendly-Timestamp" => timestamp.to_s, "X-Sendly-Signature" => signature }
    end
end
