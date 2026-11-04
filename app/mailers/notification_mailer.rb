class NotificationMailer < ApplicationMailer
  def notification_email
    @notification = params[:notification]
    return unless @notification.recipient.email.present? && @notification.recipient.email_for?(@notification.kind)

    @project = @notification.project

    mail to: @notification.recipient.email, subject: @notification.message
  end
end
