class Notification < ApplicationRecord
  KINDS = {
    "invitation" => { email_default: true, label: "Invitations" },
    "task_assigned" => { email_default: true, label: "Task assignments" },
    "mention" => { email_default: true, label: "@mentions" },
    "slot_reminder" => { email_default: true, label: "Slot reminders" },
    "followed_reply" => { email_default: false, label: "Replies on things you follow" },
    "team_departure" => { email_default: true, label: "Team departures" }
  }.freeze

  belongs_to :recipient, class_name: "Person", inverse_of: :notifications
  belongs_to :notifiable, polymorphic: true
  belongs_to :actor, class_name: "Person", optional: true, inverse_of: :acted_notifications

  enum :kind, KINDS.keys.each_with_index.to_h

  scope :unread, -> { where(read_at: nil) }

  # "Needs you": still asks something of the reader. A mention clears when read;
  # the others clear when the task, Invitation or Slot is done or has passed.
  scope :needs_you, -> {
    where(kind: "mention", read_at: nil)
      .or(where(kind: "invitation", notifiable_type: "Invitation", notifiable_id: Invitation.pending.select(:id)))
      .or(where(kind: "task_assigned", notifiable_type: "Task", notifiable_id: Task.open.select(:id)))
      .or(where(kind: "slot_reminder", notifiable_type: "Slot", notifiable_id: Slot.where(date: Date.current..).select(:id))
        .where("EXISTS (SELECT 1 FROM slot_claims WHERE slot_claims.slot_id = notifications.notifiable_id AND slot_claims.person_id = notifications.recipient_id)"))
  }

  def unread?
    read_at.nil?
  end

  def project
    return notifiable if notifiable.is_a?(Project)
    return notifiable.mentionable.project if notifiable.is_a?(Mention)

    notifiable.project
  end

  def message
    case kind
    when "invitation"
      "#{actor_name} invited you to join #{project.name}."
    when "task_assigned"
      "#{actor_name} assigned you “#{notifiable.title}”."
    when "mention"
      "#{actor_name} mentioned you in #{project.name}."
    when "slot_reminder"
      "Your Slot “#{notifiable.label}” is tomorrow."
    when "followed_reply"
      "#{actor_name} replied to something you follow in #{project.name}."
    when "team_departure"
      "A Team member left #{project.name}."
    end
  end

  # The sentence after the actor's name, for rows that show the actor as a pill.
  def message_after_actor
    return message unless actor

    message.delete_prefix(actor.name).strip
  end

  private
    def actor_name
      actor&.name || "Someone"
    end
end
