# Sends every successful change a signed-in Person makes to analytics, named like "Slot claim created".
module TracksActivity
  extend ActiveSupport::Concern

  VERBS = { "create" => "created", "update" => "updated", "destroy" => "deleted" }.freeze

  included do
    before_action { Current.demo_visitor = cookies[:demo_visitor] }
    after_action :track_activity, unless: -> { request.get? || request.head? }
  end

  private
    def track_activity
      return unless Current.person && (response.successful? || response.redirect?)

      verb = VERBS.fetch(action_name) { action_name.humanize(capitalize: false) }
      Analytics.capture(Current.person, "#{controller_name.singularize.humanize} #{verb}", controller: controller_path, action: action_name)
    end

    # Adopts the browser's own PostHog id, so its pageviews and the server's events land on one demo visitor.
    def remember_demo_visitor
      visitor = posthog_browser_id || cookies[:demo_visitor] || SecureRandom.uuid
      cookies.permanent[:demo_visitor] = { value: visitor, httponly: true, same_site: :lax, secure: Rails.env.production? }
      Current.demo_visitor = visitor
    end

    def posthog_browser_id
      state = JSON.parse(cookies["ph_#{ENV["POSTHOG_API_KEY"]}_posthog"].to_s)
      state["distinct_id"].to_s.first(200).presence if state.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end
end
