require "test_helper"

class ProjectDuplicatesTest < ActionDispatch::IntegrationTest
  test "a Leader opens the Duplicate form with defaults one year after the source" do
    sign_in_as_leader
    project = projects(:community_meal)

    get project_path(project)

    assert_select "a[href='#{new_project_duplicate_path(project)}']", text: "Duplicate"

    get new_project_duplicate_path(project)

    assert_response :success
    assert_select "h1", "Duplicate Community Meal"
    assert_select "input[name='project_duplicate[name]'][value='Community Meal (copy)']"
    assert_select "input[name='project_duplicate[start_on]'][value='2028-02-12']"
  end

  test "a Leader duplicates Project structure with every date shifted and People cleared" do
    leader = sign_in_as_leader
    projects(:building_cleanup).memberships.create!(person: leader, role: :leader)
    source = projects(:community_meal)
    source.update!(
      open_team: true,
      public_token: "source-public-token",
      done_at: Time.zone.parse("2027-02-20 10:00"),
      archived_at: Time.zone.parse("2027-02-21 10:00")
    )
    source_task = source.tasks.create!(
      title: "Set every table",
      details: "Use the blue tablecloths.",
      due_on: "2027-02-10",
      assignee: people(:volunteer),
      completed_at: Time.zone.parse("2027-02-10 17:00"),
      completed_by: leader
    )
    source_slot = source.slots.create!(
      date: "2027-02-14",
      starts_at_time: "17:30",
      label: "Serve dinner",
      capacity: 4
    )
    source_slot.slot_claims.create!(person: people(:volunteer))
    source_session = source.schedule_items.create!(date: "2027-02-18", title: "Session 3")
    linked_slot = source.slots.create!(label: "Teacher", capacity: 1, schedule_item: source_session)
    source.recipients.create!(person: people(:recipient))
    source.invitations.create!(
      organization: source.organization,
      person: people(:other_volunteer),
      inviter: leader,
      role: :volunteer
    )
    source.messages.create!(author: leader, body: "Remember the serving trays.")
    source.doc_items.create!(author: leader, kind: :document, title: "Run sheet", body: "Private notes")

    source_list = lists(:room_assignments)
    source_columns = source_list.columns.index_by(&:name)
    source_list.rows.create!(cells: {
      source_columns.fetch("Room").id.to_s => "101",
      source_columns.fetch("Beds").id.to_s => 3,
      source_columns.fetch("Arrival").id.to_s => "2027-02-11",
      source_columns.fetch("Ready").id.to_s => true,
      source_columns.fetch("Guest").id.to_s => people(:volunteer).id
    })

    assert_difference "Project.count", 1 do
      post project_duplicate_path(source), params: {
        project_duplicate: {
          name: "Community Meal 2028",
          start_on: "2028-03-15"
        }
      }
    end

    copy = leader.organization.projects.find_by!(name: "Community Meal 2028")
    assert_redirected_to project_path(copy)
    assert_equal "Prepare and serve a neighborhood dinner.", copy.description
    assert_equal Date.new(2028, 3, 15), copy.starts_on
    assert_equal Date.new(2028, 3, 15), copy.ends_on
    assert_equal [ "tasks", "schedule", "budget", "messages" ], copy.enabled_tools
    assert_not copy.open_team?
    assert_nil copy.public_token
    assert_nil copy.done_at
    assert_nil copy.archived_at
    assert_nil copy.deleted_at

    copied_task = copy.tasks.find_by!(title: "Set every table")
    assert_equal Date.new(2028, 3, 13), copied_task.due_on
    assert_equal "Use the blue tablecloths.", copied_task.details.to_plain_text
    assert_nil copied_task.assignee
    assert_nil copied_task.completed_at
    assert_nil copied_task.completed_by
    assert_equal source_task.title, copied_task.title

    assert_equal [
      [ "Arrival", Date.new(2028, 3, 15), nil, nil, nil ],
      [ "Day Two Kickoff", Date.new(2028, 3, 16), nil, nil, nil ],
      [ "Lunch", Date.new(2028, 3, 15), "12:00:00", "13:00:00", "Fellowship Hall" ],
      [ "Opening Session", Date.new(2028, 3, 15), "09:00:00", nil, nil ],
      [ "Session 3", Date.new(2028, 3, 21), nil, nil, nil ]
    ], copy.schedule_items.sort_by(&:title).map { |item|
      [
        item.title,
        item.date,
        item.starts_at_time&.strftime("%H:%M:%S"),
        item.ends_at_time&.strftime("%H:%M:%S"),
        item.location
      ]
    }

    copied_slot = copy.slots.find_by!(label: "Serve dinner")
    assert_equal Date.new(2028, 3, 17), copied_slot.date
    assert_equal "17:30:00", copied_slot.starts_at_time.strftime("%H:%M:%S")
    assert_equal 4, copied_slot.capacity
    assert_equal 0, copied_slot.claims_count

    copied_linked_slot = copy.slots.find_by!(label: "Teacher")
    assert_equal "Session 3", copied_linked_slot.schedule_item.title
    assert_equal Date.new(2028, 3, 21), copied_linked_slot.date
    assert_not_equal linked_slot.schedule_item_id, copied_linked_slot.schedule_item_id

    assert_equal [
      [ "booking", "Venue rental", 100_000, nil, "pending", nil ],
      [ "purchase", "Serving supplies", 25_000, nil, "pending", nil ]
    ], copy.budget_lines.order(:id).map { |line|
      [ line.kind, line.description, line.estimated_cents, line.actual_cents, line.status, line.responsible_person_id ]
    }

    copied_list = copy.lists.find_by!(name: "Room assignments")
    assert_equal [
      [ "Room", "text", 1 ],
      [ "Beds", "number", 2 ],
      [ "Arrival", "date", 3 ],
      [ "Ready", "checkbox", 4 ],
      [ "Guest", "person", 5 ]
    ], copied_list.columns.map { |column| [ column.name, column.column_type, column.position ] }
    copied_columns = copied_list.columns.index_by(&:name)
    copied_cells = copied_list.rows.first.cells
    assert_equal "101", copied_cells.fetch(copied_columns.fetch("Room").id.to_s)
    assert_equal 3, copied_cells.fetch(copied_columns.fetch("Beds").id.to_s)
    assert_equal "2028-03-14", copied_cells.fetch(copied_columns.fetch("Arrival").id.to_s)
    assert_equal true, copied_cells.fetch(copied_columns.fetch("Ready").id.to_s)
    assert_not copied_cells.key?(copied_columns.fetch("Guest").id.to_s)

    assert_equal 0, copy.tasks.where.not(assignee_id: nil).count
    assert_equal 0, SlotClaim.joins(:slot).where(slots: { project_id: copy.id }).count
    assert_equal 0, copy.recipients.count
    assert_equal 0, copy.invitations.count
    assert_equal 0, copy.messages.count
    assert_equal 0, copy.doc_items.count
    assert_equal 1, copy.memberships.count
    assert_equal leader, copy.owner
    assert_equal [ leader ], copy.memberships.leader.includes(:person).map(&:person)
  end

  test "a Project without a start date requires one and shifts from its earliest dated item" do
    leader = sign_in_as_leader
    source = Project.create_for(
      creator: leader,
      attributes: { name: "Undated Retreat", description: "Plan the next retreat." }
    )
    source.tasks.create!(title: "Confirm speaker", due_on: "2027-05-10")
    source.schedule_items.create!(date: "2027-05-12", title: "Welcome")
    source.slots.create!(date: "2027-05-14", label: "Registration", capacity: 2)
    source_list = source.lists.create!(name: "Milestones")
    date_column = source_list.columns.create!(name: "Date", column_type: :date, position: 1)
    source_list.rows.create!(cells: { date_column.id.to_s => "2027-05-08" })

    get new_project_duplicate_path(source)

    assert_response :success
    assert_nil css_select("input[name='project_duplicate[start_on]']").first["value"]

    assert_no_difference "Project.count" do
      post project_duplicate_path(source), params: {
        project_duplicate: { name: "Undated Retreat (copy)", start_on: "" }
      }
    end

    assert_response :unprocessable_content
    assert_select "li", "Start date can't be blank"

    post project_duplicate_path(source), params: {
      project_duplicate: { name: "Retreat 2028", start_on: "2028-01-20" }
    }

    copy = leader.organization.projects.find_by!(name: "Retreat 2028")
    assert_redirected_to project_path(copy)
    assert_equal Date.new(2028, 1, 20), copy.starts_on
    assert_equal Date.new(2028, 1, 22), copy.tasks.find_by!(title: "Confirm speaker").due_on
    assert_equal Date.new(2028, 1, 24), copy.schedule_items.find_by!(title: "Welcome").date
    assert_equal Date.new(2028, 1, 26), copy.slots.find_by!(label: "Registration").date

    copied_list = copy.lists.find_by!(name: "Milestones")
    copied_column = copied_list.columns.find_by!(name: "Date")
    assert_equal "2028-01-20", copied_list.rows.first.cells.fetch(copied_column.id.to_s)
  end

  test "an Admin duplicates a Project and becomes its Owner and sole Leader" do
    admin = sign_in_as_admin
    source = projects(:community_meal)

    get new_project_duplicate_path(source)

    assert_response :success

    post project_duplicate_path(source), params: {
      project_duplicate: { name: "Admin Copy", start_on: "2028-02-12" }
    }

    copy = admin.organization.projects.find_by!(name: "Admin Copy")
    assert_redirected_to project_path(copy)
    assert_equal admin, copy.owner
    assert_equal 1, copy.memberships.count
    assert_equal [ admin ], copy.memberships.leader.includes(:person).map(&:person)
  end

  test "a Project without any dated items uses a zero-day offset" do
    leader = sign_in_as_leader
    source = Project.create_for(
      creator: leader,
      attributes: {
        name: "Undated Checklist",
        ends_on: "2029-12-31"
      }
    )
    source.tasks.create!(title: "Choose a date later")

    post project_duplicate_path(source), params: {
      project_duplicate: { name: "Undated Checklist Copy", start_on: "2029-01-01" }
    }

    copy = leader.organization.projects.find_by!(name: "Undated Checklist Copy")
    assert_redirected_to project_path(copy)
    assert_equal Date.new(2029, 1, 1), copy.starts_on
    assert_equal Date.new(2029, 12, 31), copy.ends_on
    assert_nil copy.tasks.find_by!(title: "Choose a date later").due_on
  end

  test "a Volunteer cannot see or use Duplicate" do
    volunteer = sign_in_as_volunteer
    source = projects(:community_meal)

    get project_path(source)

    assert_select "a", text: "Duplicate", count: 0

    get new_project_duplicate_path(source)

    assert_response :not_found

    assert_no_difference "Project.count" do
      post project_duplicate_path(source), params: {
        project_duplicate: { name: "Volunteer Copy", start_on: "2028-02-12" }
      }
    end

    assert_response :not_found

    duplicate = ProjectDuplicate.new(source:, start_on: Date.new(2028, 2, 12), by: volunteer)
    duplicate.name = "Volunteer Service Copy"
    assert_no_difference "Project.count" do
      assert_raises(ActiveRecord::RecordNotFound) { duplicate.call }
    end
  end

  test "a former Leader of only an archived Project cannot duplicate it into a new Project" do
    sign_in_as_leader
    source = projects(:community_meal)
    source.update!(archived_at: Time.current)

    get project_path(source)
    assert_response :success
    assert_select "a", text: "Duplicate", count: 0

    get new_project_duplicate_path(source)
    assert_response :not_found

    assert_no_difference "Project.count" do
      post project_duplicate_path(source), params: {
        project_duplicate: { name: "Archived Volunteer Copy", start_on: "2028-02-12" }
      }
    end
    assert_response :not_found
  end

  test "25 seeded random duplicates preserve every pairwise date difference" do
    leader = sign_in_as_leader
    random = Random.new(22_031_033)

    25.times do |index|
      source_start = Date.new(2026, 1, 1) + random.rand(0..730)
      source = Project.create_for(
        creator: leader,
        attributes: {
          name: "Random source #{index}",
          starts_on: source_start,
          ends_on: source_start + random.rand(1..30),
          enabled_tools: Project::TOOLS
        }
      )
      source.tasks.create!(title: "First Task", due_on: source_start + random.rand(-90..180))
      source.tasks.create!(title: "Second Task", due_on: source_start + random.rand(-90..180))
      source.schedule_items.create!(date: source_start + random.rand(-90..180), title: "First Schedule item")
      source.schedule_items.create!(date: source_start + random.rand(-90..180), title: "Second Schedule item")
      source.slots.create!(date: source_start + random.rand(-90..180), label: "First Slot", capacity: 1)
      source.slots.create!(date: source_start + random.rand(-90..180), label: "Second Slot", capacity: 1)
      list = source.lists.create!(name: "Random dates")
      first_date = list.columns.create!(name: "First date", column_type: :date, position: 1)
      second_date = list.columns.create!(name: "Second date", column_type: :date, position: 2)
      list.rows.create!(cells: {
        first_date.id.to_s => (source_start + random.rand(-90..180)).iso8601,
        second_date.id.to_s => (source_start + random.rand(-90..180)).iso8601
      })
      offset = random.rand(-365..730)

      post project_duplicate_path(source), params: {
        project_duplicate: {
          name: "Random copy #{index}",
          start_on: (source_start + offset).iso8601
        }
      }

      copy = leader.organization.projects.find_by!(name: "Random copy #{index}")
      assert_redirected_to project_path(copy)
      assert_equal pairwise_date_differences(source), pairwise_date_differences(copy), "random source #{index}"
    end
  end

  private
    def pairwise_date_differences(project)
      dated_values(project).combination(2).map { |first, second| (second - first).to_i }
    end

    def dated_values(project)
      [ project.starts_on, project.ends_on ] +
        project.tasks.order(:title).pluck(:due_on) +
        project.schedule_items.order(:title).pluck(:date) +
        project.slots.order(:label).pluck(:date) +
        list_dates(project)
    end

    def list_dates(project)
      project.lists.order(:name).flat_map do |list|
        date_columns = list.columns.date.order(:position, :id)
        list.rows.order(:position, :id).flat_map do |row|
          date_columns.filter_map do |column|
            value = row.cells[column.id.to_s]
            Date.iso8601(value) if value.present?
          end
        end
      end
    end
end
