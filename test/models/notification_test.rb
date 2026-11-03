require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @project = projects(:community_meal)
    @person = people(:volunteer)
  end

  test "a mention needs you until it is read" do
    notification = Notifier.notify(recipient: @person, kind: "mention", notifiable: @project, email: false)

    assert_includes Notification.needs_you, notification

    notification.update!(read_at: Time.current)

    assert_not_includes Notification.needs_you, notification
  end

  test "an Invitation needs you only while it is pending" do
    invitee = people(:other_volunteer)
    invitation = @project.organization.invitations.create!(project: @project, person: invitee, inviter: people(:leader), role: :volunteer)
    notification = Notifier.notify(recipient: invitee, kind: "invitation", notifiable: invitation, actor: people(:leader), email: false)

    assert_includes Notification.needs_you, notification

    invitation.decline!

    assert_not_includes Notification.needs_you, notification
  end

  test "a Task assigned to you needs you until it is done" do
    task = @project.tasks.create!(title: "Set out chairs", assignee: @person)
    notification = Notifier.notify(recipient: @person, kind: "task_assigned", notifiable: task, actor: people(:leader), email: false)

    assert_includes Notification.needs_you, notification

    task.update!(completed_at: Time.current)

    assert_not_includes Notification.needs_you, notification
  end

  test "a Slot reminder needs you while the Slot is today or later and you still hold it" do
    slot = @project.slots.create!(date: Date.tomorrow, label: "Bring dessert", capacity: 2)
    claim = slot.slot_claims.create!(person: @person)
    notification = Notifier.notify(recipient: @person, kind: "slot_reminder", notifiable: slot, email: false)

    assert_includes Notification.needs_you, notification

    claim.destroy!

    assert_not_includes Notification.needs_you, notification
  end

  test "a Slot reminder for a Slot that has passed does not need you" do
    slot = @project.slots.create!(date: Date.yesterday, label: "Bring dessert", capacity: 2)
    slot.slot_claims.create!(person: @person)
    notification = Notifier.notify(recipient: @person, kind: "slot_reminder", notifiable: slot, email: false)

    assert_not_includes Notification.needs_you, notification
  end

  test "replies and Team departures are for your information" do
    reply = Notifier.notify(recipient: @person, kind: "followed_reply", notifiable: @project, email: false)
    departure = Notifier.notify(recipient: @person, kind: "team_departure", notifiable: @project, email: false)

    assert_not_includes Notification.needs_you, reply
    assert_not_includes Notification.needs_you, departure
  end

  test "needs you and unread combine for the bell count" do
    task = @project.tasks.create!(title: "Set out chairs", assignee: @person)
    assigned = Notifier.notify(recipient: @person, kind: "task_assigned", notifiable: task, email: false)
    departure = Notifier.notify(recipient: @person, kind: "team_departure", notifiable: @project, email: false)

    assert_equal [ assigned ], Notification.unread.needs_you.where(recipient: @person).to_a
    assert_includes Notification.unread.where(recipient: @person), departure
  end
end
