require "test_helper"
require "yaml"

class DemoOrganizationSeedTest < ActionDispatch::IntegrationTest
  PROJECT_NAMES = [
    "Church Workday",
    "Community Food Pantry Serve Day",
    "Christmas Outreach #{Date.current.year - 1}",
    "Fall Church Picnic",
    "Kids' Night",
    "Meal Train for the Alvarez Family",
    "Meal Train for the Hernandez Family",
    "Men's Retreat",
    "Men's Retreat #{Date.current.year - 1}",
    "Parking & Arrival Team",
    "Spring Church Workday",
    "Summer Kids' Night",
    "Sunday Welcome & Coffee Team",
    "Thanksgiving Baskets",
    "Vacation Bible School #{Date.current.year - 1}",
    "Vacation Bible School #{Date.current.year}",
    "Women's Fall Retreat"
  ].freeze

  test "seed builds the literal Grace Fellowship demo story" do
    travel_to Time.zone.local(2026, 10, 30, 12) do
      organization = DemoOrganization.seed!

      assert_equal 64, organization.people.count
      assert_equal 3, organization.overextended_limit
      assert_equal PROJECT_NAMES.sort, organization.projects.order(:name).pluck(:name)
      assert_equal 11, organization.projects.active.count
      assert_equal 6, organization.projects.where.not(done_at: nil).count
      assert_equal [ "Parking & Arrival Team" ], organization.projects.select { |project| !project.banner.attached? }.map(&:name)
      assert organization.projects.select { |project| project.banner.attached? }.all? { |project| project.banner.blob.metadata["organization_id"].to_s == organization.id.to_s }
      assert_equal Project::TOOLS.sort, organization.projects.flat_map(&:enabled_tools).uniq.sort
      assert_equal [ "Maria Lopez", "Sam Chen", "Grace Kim" ], Oversight.overextended(organization).map(&:name)
      assert_equal 11, Oversight.never_asked(organization).count

      ruth = organization.people.find_by!(name: "Ruth Bennett")
      assert_equal 14, Oversight.involvement(ruth).find { |entry| entry[:year] == 2026 }[:slots]

      meal_train = organization.projects.find_by!(name: "Meal Train for the Alvarez Family")
      assert_includes meal_train.enabled_tools, "recipients"
      assert meal_train.slots.where("claims_count > 0").exists?
      assert meal_train.slots.where(claims_count: 0).exists?

      picnic = organization.projects.find_by!(name: "Fall Church Picnic")
      assert_equal %w[messages signup_sheet], picnic.enabled_tools.sort
      assert picnic.public_token.present?
      assert_equal [ "Desserts", "Drinks", "Main dishes", "Setup helpers", "Sides" ], picnic.slots.order(:label).pluck(:label)
      assert_equal [ "Desserts", "Drinks", "Main dishes", "Sides" ], picnic.slots.where.not(claim_prompt: nil).order(:label).pluck(:label)
      assert picnic.slots.all? { |slot| slot.claims_count.positive? && !slot.full? }
      assert_equal 9, SlotClaim.joins(:slot).where(slots: { project_id: picnic.id }).where.not(note: nil).count
      assert_equal 2, picnic.messages.count

      recipient = meal_train.recipients.includes(:person).find_by!(people: { name: "The Alvarez Family" })
      assert_match(/\A202-555-01\d\d\z/, recipient.person.phone)
      assert_equal "planning_center", recipient.person.external_source
      assert_equal [
        [ "Allergic to tree nuts", "team" ],
        [ "Dad's surgery recovery may take 8 weeks", "leaders" ],
        [ "Drop off at the side door after 5pm", "team" ]
      ], recipient.notes.order(:body).pluck(:body, :visibility)
    end
  end

  test "seed leaves a real organization with the demo slug untouched" do
    real = organizations(:grace_fellowship)
    real.update!(name: "Grace Fellowship Church", demo: false)

    assert_no_difference -> { Person.count } do
      DemoOrganization.seed!
    end

    real.reload
    assert_not real.demo?
    assert_equal "Grace Fellowship Church", real.name
    assert_raises(ActiveRecord::RecordNotFound) { DemoOrganization.reset! }
    assert Organization.exists?(real.id)
  end

  test "reset replaces only the demo Organization and all of its dependent data" do
    other_organization = organizations(:st_example)
    other_counts = [ other_organization.people.count, other_organization.projects.count ]
    organization = DemoOrganization.seed!
    maria = organization.people.find_by!(name: "Maria Lopez")
    maria.sessions.create!(ip_address: "127.0.0.1", user_agent: "Demo reset test")
    old_session_ids = maria.sessions.ids
    old_rich_text_ids = ActionText::RichText.where(
      record: organization.projects.find_by!(name: "Meal Train for the Alvarez Family").messages
    ).ids
    vbs = organization.projects.find_by!(name: "Vacation Bible School #{Date.current.year}")
    document = vbs.doc_items.build(author: maria, kind: :file, title: "Volunteer handbook")
    document.file.attach(
      io: File.open(file_fixture("sample_upload.txt")),
      filename: "volunteer-handbook.txt",
      content_type: "text/plain"
    )
    document.save!
    old_attachment_ids = document.file.attachment.id

    DemoOrganization.reset!

    replacement = Organization.find_by!(slug: DemoOrganization::SLUG)
    assert_equal 64, replacement.people.count
    assert_equal 17, replacement.projects.count
    assert_equal other_counts, [ other_organization.reload.people.count, other_organization.projects.count ]
    assert_not Session.where(id: old_session_ids).exists?
    assert_not ActionText::RichText.where(id: old_rich_text_ids).exists?
    assert_not ActiveStorage::Attachment.exists?(old_attachment_ids)
  end

  test "seed uses the full demo story and remains idempotent" do
    travel_to Time.zone.local(2026, 10, 30, 12) do
      organization = DemoOrganization.seed!
      original_counts = [
        organization.people.count,
        organization.projects.count,
        Membership.where(project: organization.projects).count
      ]

      assert_equal organization, DemoOrganization.seed!
      assert_equal original_counts, [
        organization.people.count,
        organization.projects.count,
        Membership.where(project: organization.projects).count
      ]
      assert_equal 1, Organization.where(slug: DemoOrganization::SLUG, demo: true).count
      directory_people = organization.people.where(joined_from_project_id: nil)
      assert_equal 0, directory_people.where.not(external_source: "planning_center").count
      assert_equal 0, directory_people.where(external_id: nil).count
      assert_equal 0, organization.people.where.not(email: nil).where.not("email LIKE ?", "%@grace.example").count
      assert directory_people.all? { |person| person.phone.match?(/\A202-555-01\d\d\z/) }
      assert_equal [
        "Claire Robinson",
        "Felicia Cox",
        "George Ward",
        "Ingrid Mason",
        "Jonathan Moore",
        "Malcolm Bell",
        "Monica Grant",
        "Nina Bailey",
        "Pamela Underwood",
        "Peter Sanchez",
        "Victor Ramirez"
      ], Oversight.never_asked(organization).pluck(:name)

      retreat = organization.projects.find_by!(name: "Women's Fall Retreat")
      assert_equal 3, retreat.memberships.count
      assert_equal %w[budget list messages schedule signup_sheet tasks], retreat.enabled_tools.sort
      assert_operator retreat.tasks.count, :>=, 3
      assert_operator retreat.schedule_items.count, :>=, 3
      assert_operator retreat.slots.count, :>=, 3
      assert_operator retreat.budget_lines.count, :>=, 3
      assert_equal 0, retreat.recipients.count
      assert_operator retreat.messages.count, :>=, 2
      assert_equal 0, retreat.doc_items.count
      assert_equal [ "Packing list" ], retreat.lists.pluck(:name)

      meal_train = organization.projects.find_by!(name: "Meal Train for the Alvarez Family")
      assert_equal 29, meal_train.slots.count
      assert_equal 18, meal_train.slots.where("claims_count > 0").count
      assert_equal 11, meal_train.slots.where(claims_count: 0).count
      assert_equal 2, meal_train.messages.count
      assert meal_train.public_token.present?

      public_helpers = organization.people.where(joined_from_project: meal_train)
      assert_equal 4, public_helpers.count
      assert public_helpers.all? { |helper| helper.email.nil? && helper.external_source.nil? && helper.external_id.nil? }
      assert public_helpers.all? { |helper| helper.phone.match?(/\A\+1202555200[1-4]\z/) }
      helper_claims = SlotClaim.joins(:slot).where(person: public_helpers, slots: { project_id: meal_train.id })
      assert_equal public_helpers.count, helper_claims.select(:person_id).distinct.count
      assert_not Membership.where(person: public_helpers).exists?

      source = organization.projects.find_by!(name: "Vacation Bible School 2025")
      vbs = organization.projects.find_by!(name: "Vacation Bible School 2026")
      assert_not_nil source.done_at
      assert_equal "Maria Lopez", vbs.owner.name
      assert_equal 3, vbs.memberships.leader.count
      assert_equal 20, vbs.memberships.volunteer.count
      assert_equal [
        source.tasks.count,
        source.schedule_items.count,
        source.slots.count,
        source.budget_lines.count,
        source.lists.count
      ], [
        vbs.tasks.count,
        vbs.schedule_items.count,
        vbs.slots.count,
        vbs.budget_lines.count,
        vbs.lists.count
      ]
      assert vbs.tasks.where.not(assignee_id: nil).exists?
      assert vbs.tasks.done.exists?

      sam = organization.people.find_by!(name: "Sam Chen")
      assert_operator sam.projects.active.count, :>, organization.overextended_limit
      assert vbs.tasks.where(assignee: sam).exists?
      assert SlotClaim.joins(:slot).where(person: sam, slots: { project_id: vbs.id }).exists?

      workday = organization.projects.find_by!(name: "Church Workday")
      assert_predicate workday, :open_team?
      assert_equal Date.current + 3.weeks, workday.starts_on
      assert_equal %w[docs signup_sheet tasks], workday.enabled_tools.sort
      assert_equal 4, workday.tasks.open.where(assignee_id: nil).count
      assert_equal 7, workday.memberships.count
      assert_equal [ "Building map", "Volunteer handbook", "Workday safety notes" ], workday.doc_items.order(:title).pluck(:title)
      assert_equal "https://example.com/grace-fellowship/workday-map", workday.doc_items.find_by!(title: "Building map").url

      open_projects = organization.projects.active.where(open_team: true)
      assert_operator open_projects.count, :>=, 5
      assert_operator open_projects.where.not(id: sam.projects).count, :>=, 3
      assert organization.projects.find_by!(name: "Community Food Pantry Serve Day").public_token.present?

      [ retreat, vbs ].each do |project|
        assert project.invitations.pending.exists?
        assert project.invitations.accepted.exists?
        assert project.invitations.declined.exists?
      end
    end
  end

  test "every Tool has realistic content in at least two Projects" do
    organization = DemoOrganization.seed!
    populated = {
      "tasks" => ->(project) { project.tasks.exists? },
      "schedule" => ->(project) { project.schedule_items.exists? },
      "signup_sheet" => ->(project) { project.slots.exists? && SlotClaim.joins(:slot).where(slots: { project_id: project.id }).exists? },
      "budget" => ->(project) { project.budget_lines.exists? },
      "recipients" => ->(project) { project.recipients.exists? && project.recipients.joins(:notes).exists? },
      "messages" => ->(project) { project.messages.roots.exists? && project.messages.where.not(parent_id: nil).exists? },
      "docs" => ->(project) { project.doc_items.exists? },
      "list" => ->(project) { project.lists.joins(:rows).exists? }
    }

    Project::TOOLS.each do |tool|
      projects = organization.projects.select { |project| project.enabled_tools.include?(tool) && populated.fetch(tool).call(project) }
      assert_operator projects.count, :>=, 2, "expected #{tool} content in at least two Projects"
    end

    assert_operator Message.joins(project: :organization).joins(:comments).where(projects: { organization_id: organization.id }).count, :>=, 2
    assert_operator Mention.joins(:person).where(people: { organization_id: organization.id }).count, :>=, 2
    assert_operator organization.people.joins(:check_ins).distinct.count, :>=, 6
    assert_operator organization.people.joins(:unavailabilities).distinct.count, :>=, 3
    DemoOrganization::ROLE_EMAILS.each_value do |email|
      assert_operator organization.people.find_by!(email:).notifications.unread.count, :>=, 2
      assert organization.people.find_by!(email:).notifications.unread.in_app.exists?
    end
  end

  test "seed enqueues no mail SMS banner or LLM work and makes no provider calls" do
    jobs = [ ActionMailer::MailDeliveryJob, SmsNotificationJob, ProjectBannerFocusJob, ProjectBannerVariantsJob ]

    original_vision = ProjectBannerVision.method(:call)
    original_sendly = Messaging::Sendly.method(:new)
    ProjectBannerVision.define_singleton_method(:call) { |*| raise "seed called ProjectBannerVision" }
    Messaging::Sendly.define_singleton_method(:new) { |*| raise "seed initialized Sendly" }

    assert_no_enqueued_jobs only: jobs do
      DemoOrganization.seed!
    end
  ensure
    ProjectBannerVision.define_singleton_method(:call, original_vision) if original_vision
    Messaging::Sendly.define_singleton_method(:new, original_sendly) if original_sendly
  end

  test "two resets keep Project Person attachment and blob counts stable" do
    first = DemoOrganization.reset!
    first_counts = [
      first.projects.count,
      first.people.count,
      ActiveStorage::Attachment.count,
      ActiveStorage::Blob.count
    ]

    second = nil
    assert_no_enqueued_jobs(only: [ ActionMailer::MailDeliveryJob, SmsNotificationJob ]) { second = DemoOrganization.reset! }
    assert_equal first_counts, [
      second.projects.count,
      second.people.count,
      ActiveStorage::Attachment.count,
      ActiveStorage::Blob.count
    ]
    variant_blob_ids = ActiveStorage::VariantRecord.joins(:image_attachment).select("active_storage_attachments.blob_id")
    assert_not ActiveStorage::Blob.where.missing(:attachments).where.not(id: variant_blob_ids).exists?
  end

  test "seeded role buttons sign in as the fixed demo People" do
    DemoOrganization.seed!

    {
      "admin" => "Daniel Okafor",
      "leader" => "Maria Lopez",
      "volunteer" => "Sam Chen"
    }.each do |role, name|
      post demo_session_path(role:)

      assert_redirected_to home_path
      follow_redirect!
      assert_select "[data-signed-in-as]", "#{name}"
      delete session_path
    end
  end

  test "reset rebuilds meal Slots relative to the current date" do
    travel_to Time.zone.local(2026, 4, 10, 12) do
      organization = DemoOrganization.reset!
      slots = organization.projects.find_by!(name: "Meal Train for the Alvarez Family").slots.chronological.to_a

      assert_equal Date.new(2026, 3, 31), slots.first.date
      assert_equal Date.new(2026, 4, 28), slots.last.date
    end

    travel_to Time.zone.local(2026, 7, 20, 12) do
      organization = DemoOrganization.reset!
      slots = organization.projects.find_by!(name: "Meal Train for the Alvarez Family").slots.chronological.to_a

      assert_equal Date.new(2026, 7, 10), slots.first.date
      assert_equal Date.new(2026, 8, 7), slots.last.date
    end
  end

  test "the reset job restores the demo and is scheduled hourly" do
    organization = DemoOrganization.seed!
    organization.projects.find_by!(name: "Church Workday").destroy!
    organization.people.create!(name: "Temporary Judge", email: "judge@grace.example")

    DemoResetJob.perform_now

    replacement = Organization.find_by!(slug: DemoOrganization::SLUG)
    assert_equal 64, replacement.people.count
    assert_equal 17, replacement.projects.count
    assert_not replacement.people.exists?(name: "Temporary Judge")

    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    [ "production", "development" ].each do |environment|
      reset_schedule = recurring.dig(environment, "demo_organization_reset")
      assert_equal "DemoResetJob", reset_schedule.fetch("class")
      assert_equal "every hour", reset_schedule.fetch("schedule")
    end
  end
end
