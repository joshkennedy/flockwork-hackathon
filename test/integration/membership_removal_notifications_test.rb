require "test_helper"

class MembershipRemovalNotificationsTest < ActionDispatch::IntegrationTest
  test "removing a Team member revokes their Project notifications and follows" do
    sign_in_as_leader
    project = projects(:community_meal)
    volunteer = people(:volunteer)
    membership = memberships(:community_meal_volunteer)
    volunteer.update!(email_preferences: { "followed_reply" => true })

    post project_tasks_path(project), params: {
      task: { title: "Audit task", assignee_id: volunteer.id }
    }
    task = project.tasks.find_by!(title: "Audit task")

    delete session_path
    sign_in_as_volunteer
    post project_comments_path(project), params: {
      comment: { commentable_type: "Task", commentable_id: task.id, body: "baseline" }
    }
    get notifications_path
    assert_match "Audit task", response.body

    delete session_path
    sign_in_as_leader
    delete project_membership_path(project, membership)

    delete session_path
    sign_in_as_volunteer
    get notifications_path
    assert_no_match "Community Meal", response.body
    assert_no_match "Audit task", response.body

    delete session_path
    sign_in_as_leader
    ActionMailer::Base.deliveries.clear
    assert_no_difference -> { volunteer.notifications.where(kind: "followed_reply").count } do
      assert_no_emails do
        perform_enqueued_jobs do
          post project_comments_path(project), params: {
            comment: { commentable_type: "Task", commentable_id: task.id, body: "follow-up" }
          }
        end
      end
    end
  end
end
