if ENV["POSTHOG_API_KEY"].present?
  Rails.application.config.x.posthog = PostHog::Client.new(
    api_key: ENV["POSTHOG_API_KEY"],
    host: "https://us.i.posthog.com",
    on_error: ->(status, error) { Rails.logger.warn("PostHog error #{status}: #{error}") }
  )
  # Events are sent from a background thread; flush them before the process exits on deploy.
  at_exit { Rails.application.config.x.posthog.flush }
end
