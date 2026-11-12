class NotificationsController < ApplicationController
  before_action :authorize_notifications

  FLYOUT_LIMIT = 8

  def index
    visible = Policy.visible_notifications(Current.person)
    return render_flyout(visible) if turbo_frame_request_id == "notifications"

    @needs_you = visible.needs_you.includes(:actor, :notifiable).order(created_at: :desc, id: :desc)
    @for_information = visible.where.not(id: visible.needs_you.select(:id))
      .includes(:actor, :notifiable)
      .order(created_at: :desc, id: :desc)
      .group_by(&:project)
    @any_unread = visible.unread.exists?
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
    # The bell's flyout: what still needs the reader first, then the newest of the rest.
    def render_flyout(visible)
      newest = ->(scope) { scope.includes(:actor, :notifiable).order(created_at: :desc, id: :desc) }
      @notifications = newest.(visible.needs_you).limit(FLYOUT_LIMIT).to_a
      @notifications += newest.(visible.where.not(id: visible.needs_you.select(:id))).limit(FLYOUT_LIMIT - @notifications.size)
      @any_unread = visible.unread.exists?
      render :flyout, layout: false
    end

    def authorize_notifications
      action = action_name == "mark_all_read" ? :mark_all_read : :index
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, action, Notification)
    end
end
