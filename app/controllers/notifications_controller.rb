class NotificationsController < ApplicationController
  before_action :authorize_notifications

  def index
    @notifications = Policy.visible_notifications(Current.person)
      .includes(:actor, :notifiable)
      .order(created_at: :desc, id: :desc)
  end

  def mark_read
    notification = Policy.visible_notifications(Current.person).find(params[:id])
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :mark_read, notification)

    notification.update!(read_at: notification.read_at || Time.current)
    redirect_to notifications_path
  end

  def mark_all_read
    Policy.visible_notifications(Current.person).unread.update_all(read_at: Time.current)
    redirect_to notifications_path
  end

  private
    def authorize_notifications
      action = action_name == "mark_all_read" ? :mark_all_read : :index
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, action, Notification)
    end
end
