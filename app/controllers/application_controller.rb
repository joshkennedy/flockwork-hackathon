class ApplicationController < ActionController::Base
  include Authentication
  include TracksActivity
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :demo_organization?, :unread_notification_count

  private
    def ai_rate_limit_key
      if demo_organization?
        "session:#{Current.session.id}"
      else
        "person:#{Current.person.id}"
      end
    end

    def demo_organization?
      Current.organization&.demo?
    end

    def unread_notification_count
      @unread_notification_count ||= Policy.visible_notifications(Current.person).unread.needs_you.count
    end
end
