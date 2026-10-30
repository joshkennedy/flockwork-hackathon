class NotificationMailer < ApplicationMailer
  def notification_email
    @notification = params[:notification]
    @project = @notification.project

    mail to: @notification.recipient.email, subject: @notification.message
  end
end
