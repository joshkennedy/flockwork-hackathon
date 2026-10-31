require "test_helper"

class OversightTest < ActionDispatch::IntegrationTest
  test "Admin sees Overextended People at the default and changed limits" do
    sign_in_as_admin
    organization = organizations(:st_example)
    other_leader = people(:other_leader)
    volunteer = people(:volunteer)

    third_active_project = organization.projects.create!(name: "Neighborhood Visits", owner: other_leader)
    third_active_project.memberships.create!(person: other_leader, role: :leader)
    projects(:building_cleanup).memberships.create!(person: volunteer, role: :volunteer)

    {
      "Finished Project" => { done_at: Time.current },
      "Archived Project" => { archived_at: Time.current },
      "Deleted Project" => { deleted_at: Time.current }
    }.each do |name, state|
      project = organization.projects.create!({ name: name, owner: people(:admin) }.merge(state))
      project.memberships.create!(person: volunteer, role: :volunteer)
    end
    projects(:community_meal).recipients.create!(person: people(:recipient))

    get oversight_path

    assert_response :success
    assert_select "input[name='organization[overextended_limit]'][value='3']"
    assert_select "[data-overextended-person]", 1
    assert_select "[data-overextended-person='Lucy Leader'][data-serving-load='3']"
    assert_select "[data-overextended-person='Vic Volunteer']", 0
    assert_select "[data-overextended-person='Rowan Recipient']", 0

    patch oversight_path, params: { organization: { overextended_limit: 2 } }

    assert_redirected_to oversight_path
    assert_equal 2, organization.reload.overextended_limit
    follow_redirect!
    rows = css_select("[data-overextended-person]").map do |row|
      [ row["data-overextended-person"], row["data-serving-load"].to_i ]
    end
    assert_equal [ [ "Lucy Leader", 3 ], [ "Vic Volunteer", 2 ] ], rows
  end

  test "Admin sees only People with no Invitation or Team history as Never asked" do
    sign_in_as_admin
    organization = organizations(:st_example)

    organization.invitations.create!(
      project: projects(:community_meal),
      person: people(:other_volunteer),
      inviter: people(:leader),
      role: :volunteer,
      status: :declined,
      responded_at: Time.current
    )

    former_member = organization.people.create!(name: "Frank Former Member")
    deleted_project = organization.projects.create!(
      name: "Past Workday",
      owner: people(:admin),
      deleted_at: Time.current
    )
    deleted_project.memberships.create!(person: former_member, role: :volunteer)

    former_owner = organization.people.create!(name: "Olivia Former Owner")
    organization.projects.create!(name: "Owner History", owner: former_owner, deleted_at: Time.current)
    unasked_admin = organization.people.create!(name: "Amara Admin", admin: true)
    organization.people.create!(name: "Nora Never Asked")
    projects(:community_meal).recipients.create!(person: people(:recipient))

    get oversight_path

    assert_response :success
    names = css_select("[data-never-asked-person]").map { |row| row["data-never-asked-person"] }
    assert_equal [ "Nora Never Asked" ], names
    assert_not_includes names, "Vera Volunteer"
    assert_not_includes names, "Frank Former Member"
    assert_not_includes names, "Olivia Former Owner"
    assert_not_includes names, "Rowan Recipient"
    assert_not_includes names, unasked_admin.name
  end

  test "Recipient with no Invitation or Membership is not in never asked" do
    sign_in_as_admin
    organization = organizations(:st_example)
    cared_for = organization.people.create!(name: "Cara Cared For")
    deleted_project = organization.projects.create!(
      name: "Past Meal Train",
      owner: people(:admin),
      deleted_at: Time.current
    )
    deleted_project.recipients.create!(person: cared_for)

    assert_not_includes Oversight.never_asked(organization).pluck(:name), cared_for.name

    get oversight_path

    assert_response :success
    assert_not_includes css_select("[data-never-asked-person]").map { |row| row["data-never-asked-person"] }, cared_for.name
  end

  test "Admin sees literal current-year Involvement counts for every Person" do
    sign_in_as_admin
    involved_person = create_involvement_history

    get oversight_path

    assert_response :success
    assert_select "h2", "Involvement in 2026"
    rows = css_select("[data-involvement-person]").map do |row|
      [
        row["data-involvement-person"],
        row["data-projects"].to_i,
        row["data-tasks"].to_i,
        row["data-slots"].to_i
      ]
    end
    assert_equal [
      [ involved_person.name, 1, 1, 2 ],
      [ "Lucy Leader", 2, 0, 0 ],
      [ "Leo Leader", 1, 0, 0 ],
      [ "Vic Volunteer", 1, 0, 0 ],
      [ "Ada Admin", 0, 0, 0 ],
      [ "Rowan Recipient", 0, 0, 0 ],
      [ "Vera Volunteer", 0, 0, 0 ]
    ], rows
  end

  test "Admin sees a Person's Involvement timeline on their edit page" do
    sign_in_as_admin
    involved_person = create_involvement_history

    get edit_person_path(involved_person)

    assert_response :success
    assert_select "h2", "Involvement"
    assert_equal [ [ 2026, 1, 1, 2 ], [ 2025, 1, 2, 3 ] ], involvement_timeline_rows
  end

  test "non-Admin sees only their own Involvement and gets 404 on Oversight" do
    involved_person = create_involvement_history
    sign_in_as(involved_person)

    get edit_profile_path

    assert_response :success
    assert_select "h2", "Your Involvement"
    assert_equal [ [ 2026, 1, 1, 2 ], [ 2025, 1, 2, 3 ] ], involvement_timeline_rows

    get edit_person_path(people(:leader))
    assert_response :not_found

    get oversight_path
    assert_response :not_found
  end

  private
    def create_involvement_history
      organization = organizations(:st_example)
      person = organization.people.create!(name: "Ivy Involved", email: "ivy@st-example.test")

      travel_to Time.zone.local(2025, 4, 10, 12) do
        create_involvement_for(person, tasks: 2, slots: 3, project_name: "2025 Service")
      end

      travel_to Time.zone.local(2026, 6, 15, 12) do
        create_involvement_for(person, tasks: 1, slots: 2, project_name: "2026 Service")
      end

      person
    end

    def create_involvement_for(person, tasks:, slots:, project_name:)
      project = person.organization.projects.create!(name: project_name, owner: people(:admin))
      project.memberships.create!(person: person, role: :volunteer)
      tasks.times do |index|
        project.tasks.create!(
          title: "Completed Task #{index + 1}",
          completed_by: person,
          completed_at: Time.current
        )
      end
      slots.times do |index|
        slot = project.slots.create!(date: Date.current, label: "Claimed Slot #{index + 1}")
        slot.slot_claims.create!(person: person)
      end
    end

    def involvement_timeline_rows
      css_select("[data-involvement-year]").map do |row|
        [
          row["data-involvement-year"].to_i,
          row["data-projects"].to_i,
          row["data-tasks"].to_i,
          row["data-slots"].to_i
        ]
      end
    end
end
