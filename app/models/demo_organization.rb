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
      Organization.transaction do
        organization = Organization.find_or_create_by!(slug: SLUG) do |record|
          record.name = "Grace Fellowship"
          record.demo = true
          record.overextended_limit = 3
        end
        return organization if organization.projects.exists?

        organization.update!(name: "Grace Fellowship", demo: true, overextended_limit: 3)
        people = seed_people!(organization)
        seed_retreat!(organization, people)
        seed_meal_train!(organization, people)
        seed_vbs_projects!(organization, people)
        seed_workday!(organization, people)
        organization
      end
    end

    def reset!
      Organization.transaction do
        organization = Organization.lock.find_by(slug: SLUG)
        if organization
          raise ActiveRecord::RecordNotFound unless organization.demo?

          organization.invitations.destroy_all
          organization.destroy!
        end

        seed!
      end
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
            external_source: "planning_center",
            external_id:
          )
          seeded_people[attributes[:name]] = person
        end
      end

      def seed_retreat!(organization, people)
        grace = people.fetch("Grace Kim")
        retreat = Project.create_for(
          creator: grace,
          attributes: {
            name: "Women's Fall Retreat",
            description: "A quiet weekend for the women of Grace Fellowship to rest, connect, and grow together.",
            starts_on: Date.current + 5.weeks,
            ends_on: Date.current + 5.weeks + 2.days,
            enabled_tools: []
          }
        )

        invite!(organization, retreat, people.fetch("Maria Lopez"), grace, :volunteer, :accepted)
        invite!(organization, retreat, people.fetch("Tasha Williams"), grace, :volunteer, :accepted)
        invite!(organization, retreat, people.fetch("Abigail Turner"), grace, :volunteer, :pending)
        invite!(organization, retreat, people.fetch("Gabriel White"), grace, :volunteer, :pending)
        invite!(organization, retreat, people.fetch("Natalie King"), grace, :volunteer, :declined)
        invite!(organization, retreat, people.fetch("Isaiah Green"), grace, :leader, :declined)
        invite!(organization, retreat, people.fetch("Julia Adams"), grace, :volunteer, :pending)
      end

      def seed_meal_train!(organization, people)
        grace = people.fetch("Grace Kim")
        maria = people.fetch("Maria Lopez")
        meal_train = Project.create_for(
          creator: grace,
          attributes: {
            name: "Meal Train for the Alvarez Family",
            description: "Provide a warm dinner each evening while the Alvarez family focuses on recovery.",
            starts_on: Date.current - 10.days,
            ends_on: Date.current + 18.days,
            enabled_tools: %w[recipients signup_sheet messages]
          }
        )

        add_members(meal_train, people, {
          "Maria Lopez" => :leader,
          "Ruth Bennett" => :volunteer,
          "Aaron Price" => :volunteer,
          "Lydia Evans" => :volunteer,
          "Josiah Clark" => :volunteer,
          "Miriam Wright" => :volunteer,
          "David Hall" => :volunteer
        })

        recipient = meal_train.recipients.create!(person: people.fetch("The Alvarez Family"))
        recipient.notes.create!(organization:, author: maria, visibility: :team, body: "Allergic to tree nuts")
        recipient.notes.create!(organization:, author: maria, visibility: :team, body: "Drop off at the side door after 5pm")
        recipient.notes.create!(
          organization:,
          author: grace,
          visibility: :leaders,
          body: "Dad's surgery recovery may take 8 weeks"
        )

        meal_train.messages.create!(author: maria, body: "Thank you for helping the Alvarez family with dinners.")
        meal_train.messages.create!(author: grace, body: "Please label dishes with ingredients and your name.")

        slot_run = SlotRun.new(
          project: meal_train,
          start_date: Date.current - 10.days,
          end_date: Date.current + 18.days,
          starts_at_time: "18:00",
          label: "Dinner",
          capacity: 1
        )
        raise ActiveModel::ValidationError, slot_run unless slot_run.save

        meal_train.slots.chronological.first(14).each do |slot|
          slot.claim(people.fetch("Ruth Bennett"))
        end
      end

      def seed_vbs_projects!(organization, people)
        source = seed_previous_vbs!(people)
        maria = people.fetch("Maria Lopez")
        duplicate = ProjectDuplicate.new(source:, start_on: Date.current + 8.weeks, by: maria)
        duplicate.name = "Vacation Bible School #{Date.current.year}"
        vbs = duplicate.call

        invite!(organization, vbs, people.fetch("Elijah Brooks"), maria, :leader, :accepted)
        invite!(organization, vbs, people.fetch("Naomi Patel"), maria, :leader, :accepted)
        invite!(organization, vbs, people.fetch("Sam Chen"), maria, :volunteer, :accepted)
        VBS_VOLUNTEER_NAMES.drop(1).each do |name|
          vbs.memberships.create!(person: people.fetch(name), role: :volunteer)
        end

        invite!(organization, vbs, people.fetch("Andrew Baker"), maria, :volunteer, :pending)
        invite!(organization, vbs, people.fetch("Rebecca Nelson"), maria, :volunteer, :pending)
        invite!(organization, vbs, people.fetch("Nathan Hill"), maria, :volunteer, :pending)
        invite!(organization, vbs, people.fetch("Jasmine Mitchell"), maria, :leader, :pending)
        invite!(organization, vbs, people.fetch("Samuel Roberts"), maria, :volunteer, :declined)
        invite!(organization, vbs, people.fetch("Luke Harris"), maria, :volunteer, :declined)
        invite!(organization, vbs, people.fetch("Danielle Walker"), maria, :volunteer, :declined)
        invite!(organization, vbs, people.fetch("Thomas Allen"), maria, :volunteer, :pending)

        tasks = vbs.tasks.order(:id).to_a
        tasks.fetch(0).update!(assignee: people.fetch("Sam Chen"))
        tasks.fetch(1).update!(
          assignee: people.fetch("Tasha Williams"),
          completed_by: people.fetch("Tasha Williams"),
          completed_at: Time.current
        )
        tasks.fetch(2).update!(
          assignee: people.fetch("Jonah Lee"),
          completed_by: people.fetch("Jonah Lee"),
          completed_at: Time.current
        )
        vbs.slots.chronological.first.claim(people.fetch("Sam Chen"))
      end

      def seed_previous_vbs!(people)
        naomi = people.fetch("Naomi Patel")
        starts_on = Date.new(Date.current.year - 1, 6, 16)
        source = Project.create_for(
          creator: naomi,
          attributes: {
            name: "Vacation Bible School #{Date.current.year - 1}",
            description: "A week of Bible stories, games, crafts, and music for children in our community.",
            starts_on:,
            ends_on: starts_on + 4.days,
            enabled_tools: %w[tasks schedule signup_sheet budget list],
            done_at: Time.zone.local(Date.current.year - 1, 6, 21, 12)
          }
        )

        add_members(source, people, {
          "Elijah Brooks" => :leader,
          "Maria Lopez" => :leader
        })
        source.tasks.create!(title: "Prepare classroom supply bins", details: "Use one labeled bin for each age group.", due_on: starts_on - 7.days)
        source.tasks.create!(title: "Confirm volunteer background checks", due_on: starts_on - 14.days)
        source.tasks.create!(title: "Print family check-in sheets", due_on: starts_on - 2.days)
        source.tasks.create!(title: "Set up welcome table", due_on: starts_on - 1.day)
        source.tasks.create!(title: "Pack daily snack carts", due_on: starts_on)
        source.tasks.create!(title: "Post classroom signs", due_on: starts_on - 1.day)

        source.schedule_items.create!(date: starts_on, starts_at_time: "08:30", title: "Volunteer huddle", location: "Fellowship Hall")
        source.schedule_items.create!(date: starts_on, starts_at_time: "09:00", title: "Opening worship", location: "Sanctuary")
        source.schedule_items.create!(date: starts_on + 2.days, starts_at_time: "11:30", title: "Water games", location: "East Lawn")
        source.schedule_items.create!(date: starts_on + 4.days, starts_at_time: "11:45", title: "Family closing program", location: "Sanctuary")

        slot_run = SlotRun.new(
          project: source,
          start_date: starts_on,
          end_date: starts_on + 4.days,
          starts_at_time: "08:15",
          label: "Check-in helper",
          capacity: 3
        )
        raise ActiveModel::ValidationError, slot_run unless slot_run.save

        source.budget_lines.create!(kind: :booking, description: "Inflatable obstacle course", estimated_cents: 85_000, actual_cents: 82_500, status: :paid)
        source.budget_lines.create!(kind: :purchase, description: "Craft supplies", estimated_cents: 42_000, actual_cents: 39_850, status: :paid)
        source.budget_lines.create!(kind: :purchase, description: "Snacks and drinks", estimated_cents: 31_500, actual_cents: 30_975, status: :paid)
        source.budget_lines.create!(kind: :purchase, description: "Printed curriculum", estimated_cents: 24_000, actual_cents: 24_000, status: :paid)

        assignments = source.lists.create!(name: "Classroom assignments")
        classroom = assignments.columns.create!(name: "Classroom", column_type: :text)
        age_group = assignments.columns.create!(name: "Age group", column_type: :text)
        ready = assignments.columns.create!(name: "Ready", column_type: :checkbox)
        [
          [ "101", "Preschool", true ],
          [ "102", "Kindergarten", true ],
          [ "201", "Grades 1-2", true ],
          [ "202", "Grades 3-5", true ]
        ].each do |room, group, is_ready|
          assignments.rows.create!(cells: {
            classroom.id.to_s => room,
            age_group.id.to_s => group,
            ready.id.to_s => is_ready
          })
        end

        source
      end

      def seed_workday!(_organization, people)
        grace = people.fetch("Grace Kim")
        workday = Project.create_for(
          creator: grace,
          attributes: {
            name: "Church Workday",
            description: "Work together on practical projects that care for our building and grounds.",
            starts_on: Date.current + 3.weeks,
            ends_on: Date.current + 3.weeks,
            open_team: true,
            enabled_tools: %w[tasks signup_sheet]
          }
        )
        add_members(workday, people, {
          "Maria Lopez" => :leader,
          "Sam Chen" => :volunteer,
          "Esther Young" => :volunteer,
          "Ben Carter" => :volunteer,
          "Keisha Moore" => :volunteer,
          "Luke Harris" => :volunteer
        })
        workday.tasks.create!(title: "Wash exterior windows", due_on: workday.starts_on)
        workday.tasks.create!(title: "Spread mulch by the playground", due_on: workday.starts_on)
        workday.tasks.create!(title: "Touch up hallway paint", due_on: workday.starts_on)
        workday.tasks.create!(title: "Sort the storage room", due_on: workday.starts_on)
      end

      def add_members(project, people, members)
        members.each do |name, role|
          project.memberships.create!(person: people.fetch(name), role:)
        end
      end

      def invite!(organization, project, person, inviter, role, status)
        invitation = organization.invitations.create!(project:, person:, inviter:, role:)
        invitation.accept! if status == :accepted
        invitation.decline! if status == :declined
        invitation
      end
  end
end
