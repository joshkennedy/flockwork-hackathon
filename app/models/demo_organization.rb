# The public demo Organization. Seeding is idempotent, so the same code can run on every boot and from a nightly reset.
class DemoOrganization
  SLUG = "grace-fellowship".freeze

  PEOPLE = {
    "admin" => { name: "Daniel Okafor", email: "admin@grace.example", admin: true },
    "leader" => { name: "Maria Lopez", email: "leader@grace.example", admin: false },
    "volunteer" => { name: "Sam Chen", email: "volunteer@grace.example", admin: false }
  }.freeze

  DIRECTORY_NAMES = [
    "Grace Kim",
    "Ruth Bennett",
    "Elijah Brooks",
    "Naomi Patel",
    "Tasha Williams",
    "Owen Parker",
    "Priya Shah",
    "Marcus Reed",
    "Elena Torres",
    "Caleb Foster",
    "Aisha Johnson",
    "Jonah Lee",
    "Maya Thompson",
    "Isaac Rivera",
    "Chloe Martin",
    "Noah Davis",
    "Sofia Nguyen",
    "Ethan Wilson",
    "Leah Anderson",
    "Micah Brown",
    "Hannah Scott",
    "Lucas Martinez",
    "Zoe Campbell",
    "Aaron Price",
    "Lydia Evans",
    "Josiah Clark",
    "Miriam Wright",
    "David Hall",
    "Esther Young",
    "Ben Carter",
    "Keisha Moore",
    "Luke Harris",
    "Abigail Turner",
    "Gabriel White",
    "Natalie King",
    "Isaiah Green",
    "Julia Adams",
    "Andrew Baker",
    "Rebecca Nelson",
    "Nathan Hill",
    "Jasmine Mitchell",
    "Samuel Roberts",
    "Pamela Underwood",
    "Monica Grant",
    "Danielle Walker",
    "Thomas Allen",
    "The Alvarez Family",
    "Rachel Hernandez",
    "Jonathan Moore",
    "Claire Robinson",
    "Peter Sanchez",
    "Ingrid Mason",
    "Malcolm Bell",
    "Felicia Cox",
    "George Ward",
    "Nina Bailey",
    "Victor Ramirez"
  ].freeze

  NO_EMAIL_NAMES = [
    "Sofia Nguyen",
    "Ben Carter",
    "The Alvarez Family",
    "Ingrid Mason"
  ].freeze

  VBS_VOLUNTEER_NAMES = [
    "Sam Chen",
    "Tasha Williams",
    "Owen Parker",
    "Priya Shah",
    "Marcus Reed",
    "Elena Torres",
    "Caleb Foster",
    "Aisha Johnson",
    "Jonah Lee",
    "Maya Thompson",
    "Isaac Rivera",
    "Chloe Martin",
    "Noah Davis",
    "Sofia Nguyen",
    "Ethan Wilson",
    "Leah Anderson",
    "Micah Brown",
    "Hannah Scott",
    "Lucas Martinez",
    "Zoe Campbell"
  ].freeze

  # The "Explore as" buttons sign in by role, so the role maps to a fixed seeded Person.
  ROLE_EMAILS = PEOPLE.transform_values { |attributes| attributes[:email] }.freeze

  class << self
    def seed!
      Notifier.without_delivery do
        seeded = false
        organization = Organization.transaction do
          organization = Organization.find_or_create_by!(slug: SLUG) do |record|
            record.name = "Grace Fellowship"
            record.demo = true
            record.overextended_limit = 3
          end
          # A real church may own this slug; never adopt it, or the nightly reset would destroy it.
          next organization if !organization.demo? || organization.projects.exists?

          organization.update!(name: "Grace Fellowship", demo: true, overextended_limit: 3)
          people = seed_people!(organization)
          ProjectSeeder.new(organization:, people:).seed!
          seeded = true
          organization
        end
        prepare_banner_variants!(organization) if seeded
        organization
      end
    end

    def reset!
      existing = Organization.find_by(slug: SLUG)
      if existing
        raise ActiveRecord::RecordNotFound unless existing.demo?

        purge_demo_blobs!(existing)
      end

      Organization.transaction do
        organization = Organization.lock.find_by(slug: SLUG)
        if organization
          raise ActiveRecord::RecordNotFound unless organization.demo?

          organization.invitations.destroy_all
          organization.destroy!
        end
      end
      seed!
    end

    private
      def seed_people!(organization)
        definitions = PEOPLE.values + DIRECTORY_NAMES.map { |name| { name:, admin: false } }

        definitions.each_with_index.each_with_object({}) do |(attributes, index), seeded_people|
          external_id = "pco-#{1_000_101 + index}"
          email = attributes[:email]
          email ||= "#{attributes[:name].parameterize(separator: ".")}@grace.example" unless NO_EMAIL_NAMES.include?(attributes[:name])
          person = if email
            organization.people.find_or_initialize_by(email:)
          else
            organization.people.find_or_initialize_by(external_source: "planning_center", external_id:)
          end
          person.update!(
            name: attributes[:name],
            email:,
            phone: "202-555-#{(100 + index).to_s.rjust(4, "0")}",
            admin: attributes.fetch(:admin, false),
            skills: demo_skills(index),
            external_source: "planning_center",
            external_id:
          )
          seeded_people[attributes[:name]] = person
        end
      end

      # Two seeded skills per Person, spread by index so the Team pages always have someone to suggest.
      def demo_skills(index)
        [ Skills::SUGGESTED[index % Skills::SUGGESTED.size], Skills::SUGGESTED[(index * 5 + 3) % Skills::SUGGESTED.size] ]
      end

      def purge_demo_blobs!(organization)
        owned = ActiveStorage::Blob.where("metadata::jsonb ->> 'organization_id' = ?", organization.id.to_s).to_a
        variant_attachments = ActiveStorage::Attachment.where(
          record_type: "ActiveStorage::VariantRecord",
          record_id: ActiveStorage::VariantRecord.where(blob_id: owned.map(&:id)).select(:id)
        )
        variant_attachments.find_each(&:purge)
        ActiveStorage::Attachment.where(blob_id: owned.map(&:id)).find_each(&:purge)
        ActiveStorage::Blob.where(id: owned.map(&:id)).find_each(&:purge)
      end

      def prepare_banner_variants!(organization)
        organization.projects.with_attached_banner.find_each do |project|
          ProjectBannerVariantsJob.perform_now(project)
        end
      end
  end
end
