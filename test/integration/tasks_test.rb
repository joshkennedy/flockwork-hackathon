require "test_helper"

class TasksTest < ActionDispatch::IntegrationTest
  test "an admin cannot embed another church's blob in Task details" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("banner_small.png").open,
      filename: "banner.png",
      content_type: "image/png",
      metadata: { "organization_id" => organizations(:st_example).id }
    )
    sign_in_as_outsider
    project = projects(:outsider_project)
    project.update!(enabled_tools: project.enabled_tools + [ "tasks" ])

    assert_no_difference [ "Task.count", "ActiveStorage::Attachment.count" ] do
      post project_tasks_path(project), params: {
        task: {
          title: "Foreign image",
          details: %(<div>Foreign image</div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
        }
      }
    end

    assert_response :unprocessable_content
    assert_not project.tasks.exists?(title: "Foreign image")
  end

  test "a Leader creates, assigns, edits, unassigns, and deletes Tasks" do
    sign_in_as_leader
    project = projects(:community_meal)
    volunteer = people(:volunteer)

    assert_difference "Task.count", 1 do
      post project_tasks_path(project), params: {
        task: {
          title: "Set the tables",
          details: "Put water and silverware at every place.",
          due_on: "2027-02-11",
          assignee_id: volunteer.id
        }
      }
    end

    task = project.tasks.find_by!(title: "Set the tables")
    assert_redirected_to project_path(project)
    assert_equal volunteer, task.assignee
    assert_equal "Put water and silverware at every place.", task.details.to_plain_text

    follow_redirect!
    assert_match "Set the tables", response.body
    assert_match "Vic Volunteer", response.body

    patch project_task_path(project, task), params: {
      task: {
        title: "Set tables and chairs",
        details: "Prepare twelve tables.",
        due_on: "2027-02-10",
        assignee_id: ""
      }
    }

    assert_redirected_to project_path(project)
    task.reload
    assert_equal "Set tables and chairs", task.title
    assert_equal Date.new(2027, 2, 10), task.due_on
    assert_nil task.assignee

    assert_difference "Task.count", -1 do
      delete project_task_path(project, task)
    end

    assert_redirected_to project_path(project)
  end

  test "a Volunteer claims, unclaims, marks done, and undoes a Task" do
    volunteer = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Carry the serving trays")

    post claim_project_task_path(project, task)

    assert_redirected_to project_path(project)
    assert_equal volunteer, task.reload.assignee

    post unclaim_project_task_path(project, task)

    assert_redirected_to project_path(project)
    assert_nil task.reload.assignee

    post claim_project_task_path(project, task)
    post mark_done_project_task_path(project, task)

    assert_redirected_to project_path(project)
    task.reload
    assert_not_nil task.completed_at
    assert_equal volunteer, task.completed_by

    post reopen_project_task_path(project, task)

    assert_redirected_to project_path(project)
    task.reload
    assert_nil task.completed_at
    assert_nil task.completed_by
  end

  test "claiming an already-assigned Task does not replace its assignee" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    leader = people(:leader)
    task = project.tasks.create!(title: "Unlock the kitchen", assignee: leader)

    post claim_project_task_path(project, task)

    assert_redirected_to project_path(project)
    assert_equal leader, task.reload.assignee
    follow_redirect!
    assert_select "[data-toast-entry][data-toast-kind=alert]", text: "That Task is already taken."
  end

  test "a Leader cannot assign a Task to someone outside the Team" do
    sign_in_as_leader
    project = projects(:community_meal)

    assert_no_difference "Task.count" do
      post project_tasks_path(project), params: {
        task: {
          title: "Restricted assignment",
          assignee_id: people(:other_volunteer).id
        }
      }
    end

    assert_response :unprocessable_content
    assert_match "The person assigned must be a Team member", response.body
  end

  test "an Admin manages Tasks without joining the Team" do
    sign_in_as_admin
    project = projects(:community_meal)

    assert_difference "Task.count", 1 do
      post project_tasks_path(project), params: {
        task: { title: "Admin-created Task" }
      }
    end

    assert_redirected_to project_path(project)
  end

  test "a Leader marks an assigned Task done and reopens it" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Close the building", assignee: people(:volunteer))

    post mark_done_project_task_path(project, task)

    assert_redirected_to project_path(project)
    assert_equal leader, task.reload.completed_by

    post reopen_project_task_path(project, task)

    assert_redirected_to project_path(project)
    assert_nil task.reload.completed_at
  end

  test "a non-member gets 404 when claiming a Task" do
    sign_in_as(:other_volunteer)
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Refill water pitchers")

    post claim_project_task_path(project, task)

    assert_response :not_found
    assert_nil task.reload.assignee
  end

  test "a Person from another Organization cannot read or change a Task" do
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Refill water pitchers")
    sign_in_as_outsider

    get edit_project_task_path(project, task)
    assert_response :not_found

    patch project_task_path(project, task), params: {
      task: { title: "Changed", assignee_id: people(:outsider).id }
    }
    assert_response :not_found
    assert_equal [ "Refill water pitchers", nil ], task.reload.attributes.values_at("title", "assignee_id")

    assert_no_difference "Task.count" do
      delete project_task_path(project, task)
    end
    assert_response :not_found
  end

  test "Home lists visible open Tasks in due-date order with undated Tasks last" do
    volunteer = sign_in_as_volunteer
    meal = projects(:community_meal)
    cleanup = projects(:building_cleanup)
    cleanup.memberships.create!(person: volunteer, role: :volunteer)

    meal.tasks.create!(title: "Later meal Task", due_on: "2027-02-12", assignee: volunteer)
    soon_task = cleanup.tasks.create!(title: "Soon cleanup Task", due_on: "2027-02-01", assignee: volunteer)
    meal.tasks.create!(title: "Undated meal Task", assignee: volunteer)
    meal.tasks.create!(
      title: "Finished meal Task",
      due_on: "2027-01-01",
      assignee: volunteer,
      completed_at: Time.zone.parse("2027-01-01 12:00"),
      completed_by: volunteer
    )
    projects(:outsider_project).tasks.insert_all!([ {
      title: "Other Organization Task",
      assignee_id: volunteer.id,
      created_at: Time.current,
      updated_at: Time.current
    } ])

    get home_path

    assert_response :success
    titles = css_select("[data-task-title]").map { |node| node["data-task-title"] }
    assert_equal [ "Soon cleanup Task", "Later meal Task", "Undated meal Task" ], titles
    assert_select "[data-task-title='Soon cleanup Task']" do
      assert_select "p", text: /Building Cleanup/
      assert_select "button.task-check[aria-label=?]", "Mark Soon cleanup Task done"
    end
    assert_no_match "Finished meal Task", response.body
    assert_no_match "Other Organization Task", response.body

    post mark_done_project_task_path(cleanup, soon_task, return_to: "home")

    assert_redirected_to home_path
    assert_not_nil soon_task.reload.completed_at
  end

  test "leaving a Team unassigns that Person's Tasks on the Project" do
    volunteer = sign_in_as_volunteer
    project = projects(:community_meal)
    membership = project.memberships.find_by!(person: volunteer)
    task = project.tasks.create!(title: "Pack leftovers", assignee: volunteer)

    delete project_membership_path(project, membership)

    assert_redirected_to projects_path
    assert_nil task.reload.assignee
  end
end
