class DemoOutboundLimit
  LIMIT = 20
  WINDOW = 1.hour

  def self.allow?(organization)
    return true unless organization&.demo?

    count = Rails.cache.increment("demo-outbound:v1:organization:#{organization.id}", 1, expires_in: WINDOW)
    count.nil? || count <= LIMIT
  end
end
