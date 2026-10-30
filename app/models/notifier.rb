class Notifier
  def self.notify(recipient:, kind:, notifiable:, actor: nil, email: true)
    return if actor == recipient

    notification = recipient.notifications.create!(kind: kind, notifiable: notifiable, actor: actor)
    if email && recipient.email.present? && recipient.email_for?(kind)
      NotificationMailer.with(notification: notification).notification_email.deliver_later
    end
    notification
  end
end
