class NotificationMailer < ApplicationMailer
  def notification_email
    @notification = params[:notification]
    return unless @notification.recipient.email.present? && @notification.recipient.email_for?(@notification.kind)

    @project = @notification.project
    return if @project.archived_at?
    return unless @project.organization_id == @notification.recipient.organization_id
    can_open_public_reminder = @notification.slot_reminder? && Project.publicly_linked.exists?(@project.id)
    return unless Policy.can?(@notification.recipient, :show, @project) || can_open_public_reminder

    mail to: @notification.recipient.email, subject: @notification.message
  end
end
