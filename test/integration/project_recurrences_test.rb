require "test_helper"

class ProjectRecurrencesTest < ActionDispatch::IntegrationTest
  test "a Leader enables and disables their Project recurrence" do
    person = sign_in_as_leader
    project = projects(:community_meal)
    get edit_project_recurrence_path(project)
    assert_response :success

    assert_difference "ProjectRecurrence.count", 1 do
      patch project_recurrence_path(project), params: { project_recurrence: { frequency: "weekly", enabled: "1", creator_id: people(:outsider).id } }
    end
    assert_redirected_to project_path(project)
    recurrence = project.reload.project_recurrence
    assert recurrence.enabled?
    assert_equal person, recurrence.creator
    assert_equal project.starts_on, recurrence.anchor_on

    patch project_recurrence_path(project), params: { project_recurrence: { frequency: "monthly", enabled: "0" } }
    assert_not recurrence.reload.enabled?
    assert_equal "monthly", recurrence.frequency
  end

  test "a Volunteer and another church cannot change recurrence" do
    project = projects(:community_meal)
    sign_in_as_volunteer
    patch project_recurrence_path(project), params: { project_recurrence: { frequency: "weekly", enabled: "1" } }
    assert_response :not_found
    sign_in_as_outsider
    get edit_project_recurrence_path(project)
    assert_response :not_found
    assert_nil project.reload.project_recurrence
  end

  test "a Project needs a start date and a known rule" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(starts_on: nil)
    patch project_recurrence_path(project), params: { project_recurrence: { frequency: "daily", enabled: "1" } }
    assert_response :unprocessable_entity
    assert_nil project.reload.project_recurrence
  end
end
