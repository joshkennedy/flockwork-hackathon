class DemoAiLimit
  HOURLY_LIMIT = 200
  DAILY_LIMIT = 1_000
  MESSAGE = "The demo's AI is taking a break. You can keep going by hand."

  class Exceeded < StandardError; end

  class << self
    def allow?(organization)
      return true unless organization&.demo?

      hourly_count = Rails.cache.increment(key("hour"), 1, expires_in: 1.hour)
      return false if hourly_count && hourly_count > HOURLY_LIMIT

      daily_count = Rails.cache.increment(key("day"), 1, expires_in: 1.day)
      daily_count.nil? || daily_count <= DAILY_LIMIT
    end

    def consume!(organization)
      raise Exceeded, MESSAGE unless allow?(organization)
    end

    private
      def key(window)
        "demo-ai:v2:organization:#{DemoOrganization::SLUG}:#{window}"
      end
  end
end
