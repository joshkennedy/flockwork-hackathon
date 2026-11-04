require "test_helper"

class NotificationChannelsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_key = ENV["SENDLY_API_KEY"]
    ENV["SENDLY_API_KEY"] = "sandbox"
  end

  teardown do
    @previous_key.nil? ? ENV.delete("SENDLY_API_KEY") : ENV["SENDLY_API_KEY"] = @previous_key
  end

  test "profile saves independent channels and preserves existing email choices" do
    person = sign_in_as_volunteer
    person.update!(email_preferences: { mention: false })

    patch profile_path, params: { person: {
      phone: "+1 (202) 555-0100",
      in_app_preferences: { invitation: "0", task_assigned: "1" },
      sms_preferences: { invitation: "1", task_assigned: "0" },
      email_preferences: { invitation: "0" }
    } }

    assert_redirected_to home_path
    person.reload
    assert person.notification_for?("sms", "invitation")
    assert_not person.notification_for?("in_app", "invitation")
    assert_not person.email_for?("invitation")
    assert_not person.email_for?("mention")
    assert_equal "+12025550100", person.phone
  end

  test "SMS opt in rejects missing phone without saving preferences" do
    person = sign_in_as_volunteer

    patch profile_path, params: { person: { phone: "", sms_preferences: { invitation: "1" } } }

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /country code/
    assert_not person.reload.notification_for?("sms", "invitation")
  end

  test "profile cannot change another person or unrecognized preference keys" do
    person = sign_in_as_volunteer
    other = people(:other_volunteer)

    patch profile_path, params: { person: {
      id: other.id, admin: true, sms_preferences: { invented_event: "1" },
      in_app_preferences: { invitation: "0" }
    } }

    assert_redirected_to home_path
    assert_not person.reload.admin?
    assert_empty person.sms_preferences
    assert_not person.notification_for?("in_app", "invitation")
    assert other.reload.notification_for?("in_app", "invitation")
  end

  test "an SMS only invitation sends a response link and stays out of the inbox" do
    sign_in_as_leader
    invitee = people(:other_volunteer)
    invitee.update!(phone: "+15005550000", sms_preferences: { invitation: true },
      email_preferences: { invitation: false }, in_app_preferences: { invitation: false })
    sent_text = nil
    request = stub_sms.with do |sent|
      sent_text = JSON.parse(sent.body).fetch("text")
      true
    end

    assert_no_emails do
      perform_enqueued_jobs do
        post project_invitations_path(projects(:community_meal)), params: {
          invitation: { person_id: invitee.id, role: "volunteer" }
        }
      end
    end

    assert_redirected_to team_project_path(projects(:community_meal))
    notification = invitee.notifications.last!
    assert_equal "invitation", notification.kind
    assert_equal "msg_test", notification.sms_message_id
    assert_empty Policy.visible_notifications(invitee)
    assert_empty notification.sms_payload
    url = sent_text[%r{https?://\S+/invitations/(\S+)}, 1]
    assert_equal notification.notifiable, Invitation.find_by_token_for(:access, url)
    assert_requested request, times: 1
  end

  test "assigning a task sends SMS when all channels are enabled" do
    sign_in_as_leader
    assignee = people(:volunteer)
    assignee.update!(phone: "+15005550000", sms_preferences: { task_assigned: true })
    request = stub_sms

    assert_emails 1 do
      perform_enqueued_jobs do
        post project_tasks_path(projects(:community_meal)), params: {
          task: { title: "Set out water pitchers", assignee_id: assignee.id }
        }
      end
    end

    notification = assignee.notifications.last!
    assert notification.in_app?
    assert_equal "msg_test", notification.sms_message_id
    assert_requested request, times: 1
  end

  test "SMS only slot reminders still deduplicate when in app is off" do
    person = people(:volunteer)
    person.update!(phone: "+15005550000", sms_preferences: { slot_reminder: true },
      email_preferences: { slot_reminder: false }, in_app_preferences: { slot_reminder: false })
    slot = projects(:community_meal).slots.create!(date: Date.tomorrow, label: "Bring dessert", capacity: 1)
    slot.slot_claims.create!(person: person)
    request = stub_sms

    assert_no_emails do
      perform_enqueued_jobs do
        2.times { SlotReminderJob.perform_now }
      end
    end

    assert_equal 1, person.notifications.where(kind: :slot_reminder, notifiable: slot).count
    assert_empty Policy.visible_notifications(person)
    assert_requested request, times: 1
  end

  test "hidden notifications cannot be opened or counted in the inbox" do
    person = sign_in_as_volunteer
    person.update!(in_app_preferences: { task_assigned: false })
    task = projects(:community_meal).tasks.create!(title: "Set out chairs", assignee: person)
    notification = Notifier.notify(recipient: person, kind: "task_assigned", notifiable: task, actor: people(:leader), email: false)

    get notifications_path
    assert_response :success
    assert_select "a[href=?]", project_task_path(task.project, task), count: 0
    patch mark_read_notification_path(notification)
    assert_response :not_found
    assert_nil notification.reload.read_at
  end

  private
    def stub_sms
      stub_request(:post, Messaging::Sendly::ENDPOINT.to_s)
        .to_return(status: 201, body: { id: "msg_test", status: "queued", simulated: true }.to_json)
    end
end
