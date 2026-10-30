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

    project = creator.workspace.projects.find_by!(name: "Community Dinner")
    assert_redirected_to project_path(project)
    assert_equal creator, project.owner
    assert_predicate project.memberships.find_by!(person: creator), :leader?
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
    assert_select "p", text: "Nothing here yet", count: 2

    patch project_path(project), params: {
      project: { enabled_tools: [ "schedule" ] }
    }

    follow_redirect!
    assert_select "h2", text: "Schedule", count: 1
    assert_select "h2", text: "Tasks", count: 0
    assert_select "h2", text: "Docs & Files", count: 0
    assert_select "section[aria-labelledby='tool-schedule'] span.font-semibold", text: "Arrival"
    assert_equal [ "schedule" ], project.reload.enabled_tools
  end

  test "a Volunteer views a Project but cannot edit it" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    get projects_path

    assert_select "h2", "Community Meal"
    assert_no_match "Building Cleanup", response.body

    get project_path(project)

    assert_response :success
    assert_select "h1", "Community Meal"
    assert_select "a", text: "Edit Project", count: 0

    get edit_project_path(project)

    assert_response :not_found

    patch project_path(project), params: {
      project: { name: "Volunteer Rename" }
    }

    assert_response :not_found
    assert_equal "Community Meal", project.reload.name
  end

  test "an Admin sees every non-deleted Project in their Workspace" do
    sign_in_as_admin

    get projects_path

    assert_response :success
    assert_select "h2", "Building Cleanup"
    assert_select "h2", "Community Meal"
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

  test "a Person from another Workspace cannot find a Project or see its name in the Projects list" do
    sign_in_as_outsider
    project = projects(:community_meal)

    get project_path(project)

    assert_response :not_found

    get projects_path

    assert_response :success
    assert_select "h2", "Outsider Church Picnic"
    assert_no_match "Community Meal", response.body
  end

  test "the Workspace home links to Projects" do
    sign_in_as_leader

    get workspace_path(workspaces(:st_example))

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

  test "a Project rejects Tools outside the fixed registry" do
    sign_in_as_leader
    project = projects(:community_meal)

    patch project_path(project), params: {
      project: { enabled_tools: [ "tasks", "unknown" ] }
    }

    assert_response :unprocessable_content
    assert_select "li", "Tools contains an unknown Tool"
    assert_equal [ "tasks", "schedule", "budget" ], project.reload.enabled_tools
  end
end
