class Notifier
  def self.notify(recipient:, kind:, notifiable:, actor: nil, email: true)
    return if actor == recipient

    notification = recipient.notifications.build(kind: kind, notifiable: notifiable, actor: actor,
      in_app: recipient.notification_for?("in_app", kind))
    if recipient.notification_for?("sms", kind) && recipient.sms_phone?
      notification.sms_payload = { to: recipient.phone, text: notification.sms_text }
    end
    notification.save!

    ActiveRecord.after_all_transactions_commit do
      if email && recipient.email.present? && recipient.email_for?(kind) && DemoOutboundLimit.allow?(recipient.organization)
        if notification.invitation?
          InvitationMailer.invitation(notifiable).deliver_later
        else
          NotificationMailer.with(notification: notification).notification_email.deliver_later
        end
      end
      SmsNotificationJob.perform_later(notification.id) if notification.sms_payload.present?
    end
    notification
  end
end
