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

  private
    def actor_name
      actor&.name || "Someone"
    end
end
