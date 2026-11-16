require "test_helper"

class ProjectDebriefsTest < ActionDispatch::IntegrationTest
  test "finishing a Project offers an optional debrief that can be skipped and edited later" do
    sign_in_as_leader
    project = projects(:community_meal)
    post mark_done_project_path(project)
    assert_redirected_to project_path(project)
    follow_redirect!
    assert_response :success
    assert_select "details.actions-menu a[href='#{edit_project_debrief_path(project)}']", text: "Project Debrief"
    get project_path(project)
    assert_nil project.reload.project_debrief

    assert_difference "ProjectDebrief.count", 1 do
      patch project_debrief_path(project), params: { project_debrief: { what_worked: "Small teams", change_next_time: "Start earlier" } }
    end
    assert_redirected_to project_path(project)
    sign_in_as(:other_leader)
    assert_no_difference "ProjectDebrief.count" do
      patch project_debrief_path(project), params: { project_debrief: { what_worked: "Clear roles", change_next_time: "More setup time" } }
    end
    get edit_project_debrief_path(project)
    assert_response :success
    assert_select "textarea[name='project_debrief[what_worked]']", text: "Clear roles"
    assert_equal "More setup time", project.reload.project_debrief.change_next_time
  end

  test "a Volunteer and another church cannot read or save a debrief" do
    project = projects(:community_meal)
    project.update!(done_at: Time.current)
    sign_in_as_volunteer
    get edit_project_debrief_path(project)
    assert_response :not_found
    patch project_debrief_path(project), params: { project_debrief: { what_worked: "Unauthorized" } }
    assert_response :not_found
    sign_in_as_outsider
    get edit_project_debrief_path(project)
    assert_response :not_found
    assert_nil project.reload.project_debrief
  end

  test "unfinished Projects cannot receive a debrief and invalid answers do not overwrite saved answers" do
    sign_in_as_leader
    project = projects(:community_meal)
    patch project_debrief_path(project), params: { project_debrief: { what_worked: "Too soon" } }
    assert_response :not_found
    project.update!(done_at: Time.current)
    project.create_project_debrief!(what_worked: "Keep this")
    patch project_debrief_path(project), params: { project_debrief: { what_worked: "x" * 2001 } }
    assert_response :unprocessable_entity
    assert_equal "Keep this", project.reload.project_debrief.what_worked
  end
end
