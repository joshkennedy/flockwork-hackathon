class DemoOutboundLimit
  LIMIT = 20
  WINDOW = 1.hour

  # Demo People are shared, made-up records any visitor can edit, so mail and texts meant for them never leave.
  # Sign-in links and guest codes, which go only to the address the visitor typed, stay under the hourly limit below.
  def self.allow_for_person?(person)
    !person.organization&.demo?
  end

  def self.allow?(organization)
    return true unless organization&.demo?

    count = Rails.cache.increment("demo-outbound:v1:organization:#{organization.id}", 1, expires_in: WINDOW)
    count.nil? || count <= LIMIT
  end
end
