class NotificationMailer < ApplicationMailer
  def notification_email
    @notification = params[:notification]
    return unless @notification.recipient.email.present? && @notification.recipient.email_for?(@notification.kind)

    @project = @notification.project
    return if @project.archived_at?
    return unless Policy.can?(@notification.recipient, :show, @project)

    mail to: @notification.recipient.email, subject: @notification.message
  end
end
