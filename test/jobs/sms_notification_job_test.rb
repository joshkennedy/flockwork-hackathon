require "test_helper"

class SmsNotificationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @person = people(:volunteer)
    @person.update!(phone: "+15005550000", sms_preferences: { task_assigned: true })
    @task = projects(:community_meal).tasks.create!(title: "Set out chairs", assignee: @person)
    @notification = Notifier.notify(recipient: @person, kind: "task_assigned", notifiable: @task, actor: people(:leader))
    @request = sms_request
      .to_return(status: 201, body: { id: "msg_test", status: "delivered", simulated: true }.to_json)
    @previous_key = ENV["SENDLY_API_KEY"]
    ENV["SENDLY_API_KEY"] = "sandbox"
  end

  teardown do
    @previous_key.nil? ? ENV.delete("SENDLY_API_KEY") : ENV["SENDLY_API_KEY"] = @previous_key
  end

  test "submits once and records simulated provider acceptance" do
    2.times { SmsNotificationJob.perform_now(@notification.id) }

    assert_requested @request, times: 1
    assert_equal "msg_test", @notification.reload.sms_message_id
    assert_equal "delivered", @notification.sms_status
    assert @notification.sms_simulated?
    assert_nil @notification.sms_error
    assert_empty @notification.sms_payload
  end

  test "a timeout retry uses the original payload and idempotency key" do
    @request = sms_request.to_timeout.then.to_return(status: 201, body: { id: "msg_test", status: "queued", simulated: true }.to_json)

    assert_raises(Messaging::Sendly::RetryableError) { SmsNotificationJob.new.perform(@notification.id) }
    assert_includes @notification.reload.sms_error, "delivery is unknown"
    @task.update!(title: "Changed after timeout")
    SmsNotificationJob.perform_now(@notification.id)

    assert_requested @request, times: 2
    assert_equal "queued", @notification.reload.sms_status
    assert_nil @notification.sms_error
  end

  test "rate limits retry through the queue" do
    @request = sms_request.to_return(status: 429, body: "private provider details")

    assert_enqueued_with(job: SmsNotificationJob, args: [ @notification.id ]) do
      SmsNotificationJob.perform_now(@notification.id)
    end
    assert_equal "Sendly request failed (HTTP 429)", @notification.reload.sms_error
  end

  test "permanent provider errors do not retry" do
    @request = sms_request.to_return(status: 400, body: "private provider details")

    assert_no_enqueued_jobs do
      assert_raises(Messaging::Sendly::Error) { SmsNotificationJob.perform_now(@notification.id) }
    end
    assert_equal "Sendly request failed (HTTP 400)", @notification.reload.sms_error
    assert_equal "failed", @notification.sms_status
    assert_empty @notification.sms_payload
  end

  test "exhausting retries clears sensitive payload and records terminal failure" do
    sms_request.to_return(status: 503, body: "private provider details")
    job = SmsNotificationJob.new(@notification.id)
    4.times { job.perform_now }

    assert_no_enqueued_jobs { job.perform_now }

    assert_equal "failed", @notification.reload.sms_status
    assert_empty @notification.sms_payload
    assert_equal "Sendly request failed (HTTP 503)", @notification.sms_error
  end

  test "invalid saved payload records a terminal failure without sending" do
    @notification.update!(sms_payload: @notification.sms_payload.merge("text" => ""))

    SmsNotificationJob.perform_now(@notification.id)

    assert_equal "failed", @notification.reload.sms_status
    assert_equal "SMS payload is invalid.", @notification.sms_error
    assert_empty @notification.sms_payload
    assert_not_requested :post, Messaging::Sendly::ENDPOINT.to_s
  end

  test "opting out before delivery cancels the queued text" do
    @person.update!(sms_preferences: { task_assigned: false })
    assert_cancelled
  end

  test "changing phone numbers before delivery cancels the queued text" do
    @person.update!(phone: "+12025550100")
    assert_cancelled
  end

  test "reassignment before delivery cancels the queued text" do
    @task.update!(assignee: people(:leader))
    assert_cancelled
  end

  test "archiving the project before delivery cancels the queued text" do
    @task.project.update!(archived_at: Time.current)
    assert_cancelled
  end

  test "old jobs cannot resend outside the provider idempotency window" do
    @notification.update!(created_at: 24.hours.ago)
    assert_cancelled
  end

  test "moving a Slot cancels its queued tomorrow reminder" do
    @person.update!(sms_preferences: { slot_reminder: true })
    slot = projects(:community_meal).slots.create!(date: Date.tomorrow, label: "Serve")
    slot.claim(@person)
    @notification = Notifier.notify(recipient: @person, kind: "slot_reminder", notifiable: slot)
    assert @notification.sms_relevant?

    slot.update!(date: Date.tomorrow + 7)

    assert_cancelled
  end

  private
    def sms_request
      stub_request(:post, Messaging::Sendly::ENDPOINT.to_s)
        .with(headers: { "Idempotency-Key" => "notification-#{@notification.id}-sms" },
          body: @notification.sms_payload.merge("messageType" => "transactional").to_json)
    end

    def assert_cancelled
      SmsNotificationJob.perform_now(@notification.id)
      assert_equal "cancelled", @notification.reload.sms_status
      assert_empty @notification.sms_payload
      assert_not_requested :post, Messaging::Sendly::ENDPOINT.to_s
    end
end
