class SmsNotificationJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  retry_on Messaging::Sendly::RetryableError, wait: 30.seconds, attempts: 5 do |job, error|
    Notification.where(id: job.arguments.first, sms_status: nil)
      .update_all(sms_status: "failed", sms_payload: {}, sms_error: error.message, updated_at: Time.current)
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(notification_id)
    notification = Notification.find(notification_id)
    notification.with_lock do
      return if notification.sms_status.present? || notification.sms_payload.blank?

      recipient = notification.recipient.reload
      unless recipient.notification_for?("sms", notification.kind) &&
          recipient.phone == notification.sms_payload.fetch("to") &&
          notification.sms_relevant? && notification.created_at > 23.hours.ago
        notification.update!(sms_status: "cancelled", sms_payload: {})
        return
      end

      unless DemoOutboundLimit.allow?(recipient.organization)
        notification.update!(sms_status: "cancelled", sms_payload: {})
        return
      end

      # The saved payload and key survive a crash after Sendly accepts the request.
      response = Messaging::Sendly.new.send_sms(
        to: notification.sms_payload.fetch("to"), text: notification.sms_payload.fetch("text"),
        idempotency_key: "notification-#{notification.id}-sms")
      notification.update!(sms_message_id: response.fetch("id"), sms_status: response.fetch("status"),
        sms_simulated: response.fetch("simulated", false), sms_error: nil, sms_payload: {})
    end
  rescue Messaging::Sendly::Error => error
    attributes = { sms_error: error.message, updated_at: Time.current }
    attributes.merge!(sms_status: "failed", sms_payload: {}) unless error.is_a?(Messaging::Sendly::RetryableError)
    Notification.where(id: notification.id, sms_status: nil)
      .update_all(attributes)
    raise
  rescue ArgumentError, KeyError
    notification.update!(sms_status: "failed", sms_payload: {}, sms_error: "SMS payload is invalid.")
  end
end
