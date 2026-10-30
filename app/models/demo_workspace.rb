# The public demo Workspace. Seeding is idempotent, so the same code can run on every boot and from a nightly reset.
class DemoWorkspace
  SLUG = "grace-fellowship".freeze

  PEOPLE = {
    "admin" => { name: "Daniel Okafor", email: "admin@grace.example", admin: true },
    "leader" => { name: "Maria Lopez", email: "leader@grace.example", admin: false },
    "volunteer" => { name: "Sam Chen", email: "volunteer@grace.example", admin: false }
  }.freeze

  # The "Explore as" buttons sign in by role, so the role maps to a fixed seeded Person.
  ROLE_EMAILS = PEOPLE.transform_values { |attributes| attributes[:email] }.freeze

  def self.seed!
    workspace = Workspace.find_or_create_by!(slug: SLUG) do |record|
      record.name = "Grace Fellowship"
      record.demo = true
    end

    PEOPLE.each_value do |attributes|
      workspace.people.find_or_create_by!(email: attributes[:email]) do |person|
        person.name = attributes[:name]
        person.admin = attributes[:admin]
      end
    end

    workspace
  end
end
