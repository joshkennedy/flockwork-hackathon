require "test_helper"
require "yaml"

class DemoOrganizationSeedTest < ActionDispatch::IntegrationTest
  test "seed builds the literal Grace Fellowship demo story" do
    travel_to Time.zone.local(2026, 10, 30, 12) do
      organization = DemoOrganization.seed!

      assert_equal 60, organization.people.count
      assert_equal 3, organization.overextended_limit
      assert_equal [
        "Church Workday",
        "Meal Train for the Alvarez Family",
        "Vacation Bible School 2025",
        "Vacation Bible School 2026",
        "Women's Fall Retreat"
      ], organization.projects.order(:name).pluck(:name)
      assert_equal [ "Maria Lopez", "Grace Kim" ], Oversight.overextended(organization).map(&:name)
      assert_equal 12, Oversight.never_asked(organization).count

      ruth = organization.people.find_by!(name: "Ruth Bennett")
      assert_equal 14, Oversight.involvement(ruth).find { |entry| entry[:year] == 2026 }[:slots]

      meal_train = organization.projects.find_by!(name: "Meal Train for the Alvarez Family")
      assert meal_train.slots.where("claims_count > 0").exists?
      assert meal_train.slots.where(claims_count: 0).exists?

      recipient = meal_train.recipients.includes(:person).find_by!(people: { name: "The Alvarez Family" })
      assert_equal [
        [ "Allergic to tree nuts", "team" ],
        [ "Dad's surgery recovery may take 8 weeks", "leaders" ],
        [ "Drop off at the side door after 5pm", "team" ]
      ], recipient.notes.order(:body).pluck(:body, :visibility)
    end
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
    assert_equal 60, replacement.people.count
    assert_equal 5, replacement.projects.count
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
      assert_equal 0, organization.people.where.not(external_source: "planning_center").count
      assert_equal 0, organization.people.where(external_id: nil).count
      assert_equal 0, organization.people.where.not(email: nil).where.not("email LIKE ?", "%@grace.example").count
      assert organization.people.all? { |person| person.phone.match?(/\A202-555-01\d\d\z/) }
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
        "Rachel Hernandez",
        "Victor Ramirez"
      ], Oversight.never_asked(organization).pluck(:name)

      retreat = organization.projects.find_by!(name: "Women's Fall Retreat")
      assert_equal 3, retreat.memberships.count
      assert_empty retreat.enabled_tools
      assert_equal 0, retreat.tasks.count
      assert_equal 0, retreat.schedule_items.count
      assert_equal 0, retreat.slots.count
      assert_equal 0, retreat.budget_lines.count
      assert_equal 0, retreat.recipients.count
      assert_equal 0, retreat.messages.count
      assert_equal 0, retreat.doc_items.count
      assert_equal 0, retreat.lists.count

      meal_train = organization.projects.find_by!(name: "Meal Train for the Alvarez Family")
      assert_equal 29, meal_train.slots.count
      assert_equal 14, meal_train.slots.where("claims_count > 0").count
      assert_equal 15, meal_train.slots.where(claims_count: 0).count
      assert_equal 2, meal_train.messages.count

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
      assert_equal [ "Church Workday", "Vacation Bible School 2026" ], sam.projects.active.order(:name).pluck(:name)
      assert vbs.tasks.where(assignee: sam).exists?
      assert SlotClaim.joins(:slot).where(person: sam, slots: { project_id: vbs.id }).exists?

      workday = organization.projects.find_by!(name: "Church Workday")
      assert_predicate workday, :open_team?
      assert_equal Date.current + 3.weeks, workday.starts_on
      assert_equal 4, workday.tasks.open.where(assignee_id: nil).count
      assert_equal 7, workday.memberships.count

      [ retreat, vbs ].each do |project|
        assert project.invitations.pending.exists?
        assert project.invitations.accepted.exists?
        assert project.invitations.declined.exists?
      end
    end
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
      assert_select "p", "Signed in as #{name}"
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

  test "the reset job restores the demo and is scheduled nightly" do
    organization = DemoOrganization.seed!
    organization.projects.find_by!(name: "Church Workday").destroy!
    organization.people.create!(name: "Temporary Judge", email: "judge@grace.example")

    DemoResetJob.perform_now

    replacement = Organization.find_by!(slug: DemoOrganization::SLUG)
    assert_equal 60, replacement.people.count
    assert_equal 5, replacement.projects.count
    assert_not replacement.people.exists?(name: "Temporary Judge")

    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    [ "production", "development" ].each do |environment|
      reset_schedule = recurring.dig(environment, "demo_organization_reset")
      assert_equal "DemoResetJob", reset_schedule.fetch("class")
      assert_equal "at 3am every day", reset_schedule.fetch("schedule")
    end
  end
end
