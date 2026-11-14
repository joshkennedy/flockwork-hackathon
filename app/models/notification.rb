class Notification < ApplicationRecord
  KINDS = {
    "invitation" => { email_default: true, label: "Invitations" },
    "task_assigned" => { email_default: true, label: "Task assignments" },
    "mention" => { email_default: true, label: "@mentions" },
    "slot_reminder" => { email_default: true, label: "Slot reminders" },
    "followed_reply" => { email_default: false, label: "Replies on things you follow" },
    "team_departure" => { email_default: true, label: "Team departures" },
    "project_message" => { email_default: true, label: "Project messages" }
  }.freeze

  belongs_to :recipient, class_name: "Person", inverse_of: :notifications
  belongs_to :notifiable, polymorphic: true
  belongs_to :actor, class_name: "Person", optional: true, inverse_of: :acted_notifications

  enum :kind, KINDS.keys.each_with_index.to_h

  scope :unread, -> { where(read_at: nil) }
  scope :in_app, -> { where(in_app: true) }

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

  def sms_text
    routes = Rails.application.routes.url_helpers
    options = Rails.application.config.action_mailer.default_url_options
    url = if invitation?
      routes.invitation_url(notifiable.generate_token_for(:access), **options)
    else
      project_url_for_recipient
    end
    "Flockwork: #{message} #{url} Reply STOP to opt out."
  end

  def project_url_for_recipient
    routes = Rails.application.routes.url_helpers
    options = Rails.application.config.action_mailer.default_url_options
    if !Policy.visible_projects(recipient).exists?(project.id) && Project.publicly_linked.exists?(project.id)
      public_anchor = ActionView::RecordIdentifier.dom_id(notifiable) if notifiable.is_a?(Slot)
      routes.public_project_url(project.public_token, anchor: public_anchor, **options)
    else
      routes.project_url(project, anchor:, **options)
    end
  end

  def sms_relevant?
    return false unless notifiable && project && project.organization_id == recipient.organization_id
    return false if project.deleted_at? || project.archived_at?
    return notifiable.pending? && notifiable.person_id == recipient_id if invitation?
    if slot_reminder?
      can_open = Policy.can?(recipient, :show, project) || Project.publicly_linked.exists?(project.id)
      return can_open && notifiable.date == Date.tomorrow && notifiable.slot_claims.exists?(person_id: recipient_id)
    end
    return false unless Policy.can?(recipient, :show, project)
    return notifiable.assignee_id == recipient_id && !notifiable.completed_at? if task_assigned?

    true
  end

  def project
    return notifiable if notifiable.is_a?(Project)
    return notifiable.mentionable.project if notifiable.is_a?(Mention)

    notifiable.project
  end

  # The element on the project page this points at. The page opens the tab holding it and scrolls to it.
  def anchor
    target = notifiable.is_a?(Mention) ? notifiable.mentionable : notifiable
    case target
    when Comment, Message, Task, Slot then ActionView::RecordIdentifier.dom_id(target)
    when Project then "tab-team" if team_departure?
    end
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
    when "project_message"
      "#{actor_name} posted a message in #{project.name}."
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
