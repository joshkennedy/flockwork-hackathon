require "test_helper"

class ProjectLifecycleTest < ActionDispatch::IntegrationTest
  test "a Leader marks a Project done and reopens it" do
    sign_in_as_leader
    project = projects(:community_meal)

    post mark_done_project_path(project)

    assert_redirected_to edit_project_debrief_path(project)
    assert_not_nil project.reload.done_at

    get projects_path

    assert_select "section[aria-labelledby='group-done'] h3", text: project.name

    post reopen_project_path(project)

    assert_redirected_to project_path(project)
    assert_nil project.reload.done_at
  end

  test "a Volunteer cannot mark a Project done" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    post mark_done_project_path(project)

    assert_response :not_found
    assert_nil project.reload.done_at
  end

  test "only the Owner archives and unarchives a Project" do
    sign_in_as_leader
    project = projects(:community_meal)

    post archive_project_path(project)

    assert_redirected_to archived_projects_path
    assert_not_nil project.reload.archived_at

    get projects_path

    assert_no_match "Community Meal", response.body

    get archived_projects_path

    assert_select "h2", "Community Meal"

    post unarchive_project_path(project)

    assert_redirected_to project_path(project)
    assert_nil project.reload.archived_at

    sign_in_as(:other_leader)

    post archive_project_path(project)

    assert_response :not_found
    assert_nil project.reload.archived_at
  end

  test "Archive confirms that the Project becomes read-only" do
    sign_in_as_leader
    project = projects(:community_meal)

    get project_path(project)

    assert_response :success
    assert_select "form[action='#{archive_project_path(project)}'][data-turbo-confirm='Archive “Community Meal”? It becomes read-only for everyone until you unarchive it.'] button", text: "Archive"
  end

  test "the Owner transfers ownership to another Leader on the Team" do
    sign_in_as_leader
    project = projects(:community_meal)
    new_owner = people(:other_leader)

    patch transfer_ownership_project_path(project), params: { new_owner_id: new_owner.id }

    assert_redirected_to project_path(project)
    assert_equal new_owner, project.reload.owner

    patch transfer_ownership_project_path(project), params: { new_owner_id: people(:volunteer).id }

    assert_response :not_found
    assert_equal new_owner, project.reload.owner
  end

  test "an Admin deletes a Project and a Leader can no longer open it" do
    sign_in_as_admin
    project = projects(:community_meal)

    delete project_path(project)

    assert_redirected_to projects_path
    assert_not_nil project.reload.deleted_at

    sign_in_as_leader

    get project_path(project)

    assert_response :not_found
  end

  test "deleted Projects appear in the Admin deleted view and can be restored" do
    sign_in_as_admin
    project = projects(:community_meal)
    project.update!(deleted_at: Time.current)

    get deleted_projects_path

    assert_response :success
    assert_select "h2", "Community Meal"
    assert_select "button", text: "Restore"

    post restore_project_path(project)

    assert_redirected_to project_path(project)
    assert_nil project.reload.deleted_at
  end

  test "a non-Admin cannot see the deleted Projects view" do
    sign_in_as_leader

    get deleted_projects_path

    assert_response :not_found
  end
end
