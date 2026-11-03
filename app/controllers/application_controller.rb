class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :unread_notification_count

  private
    def unread_notification_count
      @unread_notification_count ||= Policy.visible_notifications(Current.person).unread.needs_you.count
    end
end
