require "test_helper"

class ProjectsTest < ActionDispatch::IntegrationTest
  test "starting a Project makes the creator its Owner and a Leader" do
    creator = sign_in_as_leader

    assert_difference [ "Project.count", "Membership.count" ], 1 do
      post projects_path, params: {
        project: {
          name: "Community Dinner",
          description: "Serve dinner to our neighbors.",
          starts_on: "2027-03-12",
          ends_on: "2027-03-13"
        }
      }
    end

    project = creator.organization.projects.find_by!(name: "Community Dinner")
    assert_redirected_to project_path(project)
    assert_equal creator, project.owner
    assert_predicate project.memberships.find_by!(person: creator), :leader?
    assert_equal [ "messages" ], project.enabled_tools
  end

  test "a Leader who unchecks every Tool gets a Project with none" do
    creator = sign_in_as_leader

    post projects_path, params: { project: { name: "Quiet Project", enabled_tools: [ "" ] } }

    assert_empty creator.organization.projects.find_by!(name: "Quiet Project").enabled_tools
  end

  test "a Planner Project starts with Messages on" do
    sign_in_as_leader

    post start_planner_projects_path, params: { planning_kind: "retreat" }

    assert_includes Project.order(:id).last.enabled_tools, "messages"
  end

  test "an invalid manual Project ties its error to the name field" do
    sign_in_as_leader

    post projects_path, params: { project: { name: "" } }

    assert_response :unprocessable_content
    assert_select "[role='alert']", text: /Fix these to continue:/
    assert_select "input#project_name[aria-invalid='true'][aria-describedby='project_name_error']"
    assert_select "p#project_name_error.text-danger", text: "Name can't be blank"
  end

  test "a Leader edits the Project name, description, and dates" do
    sign_in_as_leader
    project = projects(:community_meal)

    patch project_path(project), params: {
      project: {
        name: "Neighborhood Supper",
        description: "Welcome our neighbors with dinner.",
        starts_on: "2027-02-19",
        ends_on: "2027-02-20",
        enabled_tools: project.enabled_tools
      }
    }

    assert_redirected_to project_path(project)
    assert_equal "Saved Neighborhood Supper.", flash[:notice]
    follow_redirect!
    assert_select "h1", "Neighborhood Supper"
    assert_select "p", "Welcome our neighbors with dinner."
    assert_equal "Neighborhood Supper", project.reload.name
    assert_equal "Welcome our neighbors with dinner.", project.description
    assert_equal Date.new(2027, 2, 19), project.starts_on
    assert_equal Date.new(2027, 2, 20), project.ends_on
  end

  test "a Leader toggles Tools and only enabled Tools appear on the Project page" do
    sign_in_as_leader
    project = projects(:community_meal)

    patch project_path(project), params: {
      project: { enabled_tools: [ "tasks", "docs" ] }
    }

    assert_redirected_to project_path(project)
    follow_redirect!
    assert_select "h2", text: "Tasks", count: 1
    assert_select "h2", text: "Docs & Files", count: 1
    assert_select "h2", text: "Schedule", count: 0
    assert_select "h2", text: "Sign-up sheet", count: 0
    assert_select "h2", text: "Budget", count: 0
    assert_select "h2", text: "Recipients", count: 0
    assert_select "h2", text: "Messages", count: 0
    assert_select "h2", text: "List", count: 0
    assert_select "section[aria-labelledby='tool-tasks'] p", text: "No open Tasks", count: 1
    assert_select "section[aria-labelledby='tool-docs'] p", text: "No items yet", count: 1

    patch project_path(project), params: {
      project: { enabled_tools: [ "schedule" ] }
    }

    follow_redirect!
    assert_select "h2", text: "Schedule", count: 1
    assert_select "h2", text: "Tasks", count: 0
    assert_select "h2", text: "Docs & Files", count: 0
    assert_select "section[aria-labelledby='tool-schedule'] p.text-heading", text: "Arrival"
    assert_equal [ "schedule" ], project.reload.enabled_tools
  end

  test "a Leader can reach Tool settings from the Project page" do
    sign_in_as_leader
    project = projects(:community_meal)

    get project_path(project)

    assert_response :success
    assert_select "details.actions-menu a[href='#{edit_project_path(project, anchor: "project-tools")}']", text: "Manage Tools"

    get edit_project_path(project, anchor: "project-tools")

    assert_select "fieldset#project-tools legend", text: "Tools"
  end

  test "a Volunteer views a Project but cannot edit it" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    get projects_path

    assert_select "h3", "Community Meal"
    assert_no_match "Building Cleanup", response.body

    get project_path(project)

    assert_response :success
    assert_select "h1", "Community Meal"
    assert_select "a", text: "Edit Project", count: 0
    assert_select "a", text: "Rename", count: 0

    get edit_project_path(project)

    assert_response :not_found

    patch project_path(project), params: {
      project: { name: "Volunteer Rename" }
    }

    assert_response :not_found
    assert_equal "Community Meal", project.reload.name
  end

  test "a Volunteer sees who will add work when a Project has no Tools" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: [])

    get project_path(project)

    assert_response :success
    assert_select "[data-empty-project]", text: "Nothing planned yet. Leaders add Tools here."
  end

  test "a Volunteer cannot open or submit any Project creation entry point" do
    sign_in_as_volunteer

    get projects_path
    assert_response :success
    assert_select "a[href='#{new_project_path}']", count: 0

    get new_project_path
    assert_response :not_found

    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "Volunteer Project" } }
    end
    assert_response :not_found

    assert_no_difference "Project.count" do
      post start_planner_projects_path, params: { planning_kind: "retreat" }
    end
    assert_response :not_found

    assert_no_difference "Project.count" do
      post start_meal_planner_projects_path
    end
    assert_response :not_found

    get oversight_path
    assert_response :not_found

    get search_person_path(people(:other_volunteer))
    assert_response :not_found
  end

  test "a Leader may use every Project creation entry point" do
    sign_in_as_leader

    assert_project_creation_entry_points_work
  end

  test "an Admin may use every Project creation entry point" do
    sign_in_as_admin

    assert_project_creation_entry_points_work
  end

  test "an Admin sees every non-deleted Project in their Organization" do
    sign_in_as_admin

    get projects_path

    assert_response :success
    assert_select "h3", "Building Cleanup"
    assert_select "h3", "Community Meal"
    assert_no_match "Outsider Church Picnic", response.body
  end

  test "a deleted Project is hidden even from an Admin" do
    sign_in_as_admin
    project = projects(:community_meal)
    project.update_column(:deleted_at, Time.current)

    get projects_path

    assert_response :success
    assert_no_match "Community Meal", response.body

    get project_path(project)

    assert_response :not_found
  end

  test "a non-member cannot find a Project or see its name in the Projects list" do
    sign_in_as(:other_volunteer)
    project = projects(:community_meal)

    get project_path(project)

    assert_response :not_found

    get projects_path

    assert_response :success
    assert_no_match "Community Meal", response.body
  end

  test "a Person from another Organization cannot find a Project or see its name in the Projects list" do
    sign_in_as_outsider
    project = projects(:community_meal)

    get project_path(project)

    assert_response :not_found

    get projects_path

    assert_response :success
    assert_select "h3", "Outsider Church Picnic"
    assert_no_match "Community Meal", response.body
  end

  test "the Organization home links to Projects" do
    sign_in_as_leader

    get home_path

    assert_select "a[href='#{projects_path}']", "Projects"
  end

  test "a Project rejects an end date before its start date" do
    sign_in_as_leader
    project = projects(:community_meal)

    patch project_path(project), params: {
      project: {
        starts_on: "2027-02-20",
        ends_on: "2027-02-19"
      }
    }

    assert_response :unprocessable_content
    assert_select "li", "End date must be on or after the start date"
    assert_equal Date.new(2027, 2, 12), project.reload.starts_on
    assert_equal Date.new(2027, 2, 12), project.ends_on
  end

  test "Project forms cap names at 120 characters and reject longer requests" do
    sign_in_as_leader

    get new_project_path(manual: true)
    assert_response :success
    assert_select "input[name='project[name]'][maxlength='120']"

    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "P" * 121 } }
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /Name is too long \(maximum is 120 characters\)/
  end

  test "a Project rejects Tools outside the fixed registry" do
    sign_in_as_leader
    project = projects(:community_meal)

    patch project_path(project), params: {
      project: { enabled_tools: [ "tasks", "unknown" ] }
    }

    assert_response :unprocessable_content
    assert_select "li", "Tools contains an unknown Tool"
    assert_equal [ "tasks", "schedule", "budget", "messages" ], project.reload.enabled_tools
  end

  test "the Projects list groups by timing and says what each Project needs" do
    sign_in_as_admin
    projects(:community_meal).update!(starts_on: Date.current + 10, ends_on: Date.current + 10, enabled_tools: %w[signup_sheet])
    projects(:community_meal).slots.create!(date: Date.current + 10, label: "Dinner", capacity: 1)
    projects(:building_cleanup).update!(done_at: Time.current)

    get projects_path

    assert_select "section[aria-labelledby='group-coming-up'] h3", "Community Meal"
    assert_select "section[aria-labelledby='group-coming-up'] .badge-need", "1 dinner still needs someone"
    assert_select "section[aria-labelledby='group-done'] h3", "Building Cleanup"
  end

  private
    def assert_project_creation_entry_points_work
      get projects_path
      assert_response :success
      assert_select "a[href='#{new_project_path}']", text: "Start a Project"

      get new_project_path
      assert_response :success

      assert_difference "Project.count", 1 do
        post projects_path, params: { project: { name: "Manual Project #{Person.maximum(:id)}" } }
      end
      assert_response :redirect

      assert_difference "Project.count", 1 do
        post start_planner_projects_path, params: { planning_kind: "retreat" }
      end
      assert_response :see_other

      assert_difference "Project.count", 1 do
        post start_meal_planner_projects_path
      end
      assert_response :see_other
    end
end
