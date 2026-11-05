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
    @clock = Time.current.to_i
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

  test "opt in from the old number does not re-enable SMS on a changed phone" do
    post_event("evt_1", "message.opt_out", "+15005550000")
    @volunteer.update!(phone: "+15005550111")
    post_event("evt_2", "message.opt_in", "+15005550000")

    assert_response :ok
    assert_not @volunteer.reload.notification_for?("sms", "task_assigned")
    assert @leader.reload.notification_for?("sms", "invitation")
    assert_not SmsOptOut.blocked?("+15005550000")
  end

  test "a late START retried after a newer STOP does not undo it" do
    post_event("evt_1", "message.opt_out", "+15005550000", created: 100)
    post_event("evt_2", "message.opt_out", "+15005550000", created: 300)
    post_event("evt_3", "message.opt_in", "+15005550000", created: 200)

    assert_response :ok
    assert SmsOptOut.blocked?("+15005550000")
    assert_not @volunteer.reload.notification_for?("sms", "task_assigned")
    assert_not @leader.reload.notification_for?("sms", "invitation")
    assert SmsWebhookEvent.exists?(event_id: "evt_3")
  end

  test "a late STOP older than the latest START is ignored" do
    post_event("evt_1", "message.opt_out", "+15005550000", created: 100)
    post_event("evt_2", "message.opt_in", "+15005550000", created: 300)
    post_event("evt_3", "message.opt_out", "+15005550000", created: 200)

    assert_not SmsOptOut.blocked?("+15005550000")
    assert @volunteer.reload.notification_for?("sms", "task_assigned")
  end

  test "every transition takes the per-phone advisory lock before reading the row" do
    %w[opt_out! opt_in!].each do |transition|
      statements = []
      callback = ->(*, payload) { statements << payload[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { SmsOptOut.public_send(transition, "+15005559999", at: Time.current) }

      lock = statements.index { |sql| sql.include?("pg_advisory_xact_lock(hashtext('+15005559999'))") }
      read = statements.index { |sql| sql.match?(/SELECT.*FROM "sms_opt_outs"/) }
      assert lock, "#{transition} did not lock"
      assert_operator lock, :<, read
    end
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
    def post_event(id, type, phone, timestamp: Time.current.to_i, signature: nil, secret: "whsec_test", created: @clock += 1)
      body = { id:, type:, created:, data: { object: { id: "msg_#{id}", from: phone, to: "+18335550100", direction: "inbound" } } }.to_json
      signature ||= "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")}"
      post "/webhooks/sendly", params: body,
        headers: { "Content-Type" => "application/json", "X-Sendly-Timestamp" => timestamp.to_s, "X-Sendly-Signature" => signature }
    end
end
