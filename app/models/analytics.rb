# Product analytics in PostHog. Every call is a no-op unless POSTHOG_API_KEY is set (see config/initializers/posthog.rb).
module Analytics
  def self.client = Rails.configuration.x.posthog

  def self.capture(person, event, properties = {})
    return unless client

    client.capture(
      distinct_id: distinct_id(person),
      event:,
      # $set keeps the Person's role current, so counts of admins, leaders, and volunteers stay right after a promotion.
      properties: properties.merge("$set" => person_properties(person)),
      groups: { organization: person.organization_id.to_s }
    )
  end

  def self.identify(person)
    return unless client

    organization = person.organization
    # Demo visitors stay anonymous so a later real sign-up merges their demo history into the new Person.
    client.identify(distinct_id: distinct_id(person), properties: person_properties(person)) unless organization.demo?
    client.group_identify(
      group_type: "organization",
      group_key: organization.id.to_s,
      properties: { name: organization.name, demo: organization.demo?, created_at: organization.created_at }
    )
  end

  # Everyone in the demo signs in as the same seeded Person for their role, so the demo tracks the visitor instead.
  def self.distinct_id(person)
    (Current.demo_visitor if person.organization.demo?) || "person_#{person.id}"
  end

  def self.role(person)
    if person.admin? then "admin" elsif person.memberships.leader.exists? then "leader" else "volunteer" end
  end

  def self.person_properties(person)
    properties = { role: role(person), organization_id: person.organization_id, demo: person.organization.demo?, created_at: person.created_at }
    # Volunteers stay pseudonymous; only Admins, the church's account holders, are sent with name and email.
    properties.merge!(name: person.name, email: person.email) if person.admin? && !person.organization.demo?
    properties
  end
end
