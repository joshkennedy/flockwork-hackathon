require "test_helper"

class OpenTeamTest < ActionDispatch::IntegrationTest
  test "a Leader toggles Open Team on the Project edit form" do
    sign_in_as_leader
    project = projects(:community_meal)

    get edit_project_path(project)
    assert_select "input[name='project[open_team]'][type='checkbox']"

    patch project_path(project), params: {
      project: {
        name: project.name,
        description: project.description,
        starts_on: project.starts_on,
        ends_on: project.ends_on,
        open_team: "1",
        enabled_tools: project.enabled_tools
      }
    }

    assert_redirected_to project_path(project)
    assert project.reload.open_team?
  end

  test "a Volunteer on another Project sees an Open Team Project in Get involved and can view it without Team access" do
    sign_in_as(:other_leader)
    project = projects(:building_cleanup)
    patch project_path(project), params: {
      project: {
        name: project.name,
        description: project.description,
        starts_on: project.starts_on,
        ends_on: project.ends_on,
        open_team: "1",
        enabled_tools: [ "schedule" ]
      }
    }
    assert project.reload.open_team?

    sign_in_as_volunteer

    get get_involved_path
    assert_response :success
    assert_select "a", text: "Building Cleanup"

    get project_path(project)
    assert_response :success
    assert_select "h1", "Building Cleanup"
    assert_select "a", text: "View Team", count: 0
    assert_select "li", text: /Lucy Leader/, count: 0
    assert_select "section[aria-labelledby='tool-schedule']"

    get team_project_path(project)
    assert_response :not_found
  end

  test "a Volunteer joins an Open Team Project with one POST and becomes a Volunteer" do
    sign_in_as(:other_leader)
    project = projects(:building_cleanup)
    patch project_path(project), params: {
      project: { open_team: "1", enabled_tools: project.enabled_tools }
    }

    volunteer = sign_in_as_volunteer

    assert_difference "Membership.count", 1 do
      post join_project_path(project)
    end
    assert_redirected_to project_path(project)
    membership = project.memberships.find_by!(person: volunteer)
    assert_predicate membership, :volunteer?

    assert_no_difference "Membership.count" do
      post join_project_path(project)
    end
    assert_redirected_to project_path(project)
  end

  test "joining a Project that is not Open Team responds as not found" do
    volunteer = sign_in_as_volunteer
    project = projects(:community_meal)
    assert_not project.open_team?

    assert_no_difference "Membership.count" do
      post join_project_path(project)
    end
    assert_response :not_found
  end

  test "turning Open Team off hides the Project from a non-member again" do
    sign_in_as(:other_leader)
    project = projects(:building_cleanup)
    patch project_path(project), params: { project: { open_team: "1" } }

    sign_in_as_volunteer
    get project_path(project)
    assert_response :success

    sign_in_as(:other_leader)
    patch project_path(project), params: { project: { open_team: "0" } }
    assert_not project.reload.open_team?

    sign_in_as_volunteer
    get project_path(project)
    assert_response :not_found
    get get_involved_path
    assert_select "a", text: "Building Cleanup", count: 0
  end

  test "a Person in another Organization never sees another Organization's Open Team Project" do
    sign_in_as(:other_leader)
    project = projects(:building_cleanup)
    patch project_path(project), params: { project: { open_team: "1" } }

    sign_in_as_outsider

    get get_involved_path
    assert_response :success
    assert_select "a", text: "Building Cleanup", count: 0

    get project_path(project)
    assert_response :not_found
  end

  test "Get involved offers open Teams first and lists the ones you're on" do
    projects(:building_cleanup).update!(open_team: true)
    projects(:community_meal).update!(open_team: true)
    sign_in_as_volunteer

    get get_involved_path

    assert_select "section[aria-labelledby='open-teams-heading'] li", text: /Building Cleanup/
    assert_select "section[aria-labelledby='open-teams-heading'] a.btn[href=?]", project_path(projects(:building_cleanup)), "View Project"
    assert_select "section[aria-labelledby='joined-teams-heading'] li", text: /Community Meal.*On the Team/m
    assert_select "section[aria-labelledby='open-teams-heading'] li", text: /Community Meal/, count: 0
  end
end
