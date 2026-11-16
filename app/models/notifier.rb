class Notifier
  DELIVERY_SUPPRESSION_KEY = :flockwork_notifier_delivery_suppression

  def self.without_delivery
    previous = ActiveSupport::IsolatedExecutionState[DELIVERY_SUPPRESSION_KEY]
    ActiveSupport::IsolatedExecutionState[DELIVERY_SUPPRESSION_KEY] = true
    yield
  ensure
    ActiveSupport::IsolatedExecutionState[DELIVERY_SUPPRESSION_KEY] = previous
  end

  def self.notify(recipient:, kind:, notifiable:, actor: nil, email: true)
    return if actor == recipient

    delivery_enabled = !ActiveSupport::IsolatedExecutionState[DELIVERY_SUPPRESSION_KEY]
    notification = recipient.notifications.build(kind: kind, notifiable: notifiable, actor: actor,
      in_app: recipient.notification_for?("in_app", kind))
    if recipient.notification_for?("sms", kind) && recipient.sms_phone?
      notification.sms_payload = { to: recipient.phone, text: notification.sms_text }
    end
    notification.save!

    ActiveRecord.after_all_transactions_commit do
      if delivery_enabled && email && !notification.project.archived_at? && recipient.email.present? && recipient.email_for?(kind) && DemoOutboundLimit.allow_for_person?(recipient)
        if notification.invitation?
          InvitationMailer.invitation(notifiable).deliver_later
        else
          NotificationMailer.with(notification: notification).notification_email.deliver_later
        end
      end
      SmsNotificationJob.perform_later(notification.id) if delivery_enabled && notification.sms_payload.present?
    end
    notification
  end
end
