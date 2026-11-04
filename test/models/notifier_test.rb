require "test_helper"

class NotifierTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @person = people(:volunteer)
    @project = projects(:community_meal)
    @task = @project.tasks.create!(title: "Set out chairs", assignee: @person)
  end

  test "all eight channel combinations route independently" do
    [ true, false ].repeated_permutation(3) do |in_app, email, sms|
      @person.update!(phone: "+12025550100", in_app_preferences: { task_assigned: in_app },
        email_preferences: { task_assigned: email }, sms_preferences: { task_assigned: sms })
      clear_enqueued_jobs

      notification = nil
      assert_enqueued_jobs(email ? 1 : 0, only: ActionMailer::MailDeliveryJob) do
        assert_enqueued_jobs(sms ? 1 : 0, only: SmsNotificationJob) do
          notification = Notifier.notify(recipient: @person, kind: "task_assigned", notifiable: @task, actor: people(:leader))
        end
      end
      assert_equal in_app, notification.in_app?
      assert_equal in_app, Policy.visible_notifications(@person).exists?(id: notification.id)
      assert_equal sms, notification.sms_payload.present?
    end
  end

  test "existing defaults and email opt outs survive" do
    @person.update!(email_preferences: { invitation: false })

    Notification::KINDS.each do |kind, settings|
      assert @person.notification_for?("in_app", kind)
      assert_not @person.notification_for?("sms", kind)
      assert_equal(kind == "invitation" ? false : settings.fetch(:email_default), @person.email_for?(kind))
    end
  end

  test "SMS requires an international phone number only when enabled" do
    @person.update!(phone: "202-555-0100")
    @person.sms_preferences = { task_assigned: true }

    assert_not @person.valid?
    assert_includes @person.errors[:phone].join, "country code"

    @person.phone = "+1 (202) 555-0100"
    assert @person.valid?
    assert_equal "+12025550100", @person.phone
  end

  test "SMS payload remains unchanged after the task changes" do
    @person.update!(phone: "+12025550100", sms_preferences: { task_assigned: true })
    notification = Notifier.notify(recipient: @person, kind: "task_assigned", notifiable: @task, actor: people(:leader))
    payload = notification.sms_payload.deep_dup

    @task.update!(title: "A different title")

    assert_equal payload, notification.reload.sms_payload
    assert_includes payload.fetch("text"), "Set out chairs"
    assert_includes payload.fetch("text"), "Reply STOP"
    assert_includes payload.fetch("text"), "/projects/#{@project.id}"
  end
end
