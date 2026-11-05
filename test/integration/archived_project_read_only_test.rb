require "test_helper"

class ArchivedProjectReadOnlyTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @project.update!(enabled_tools: @project.enabled_tools + [ "signup_sheet", "docs" ], archived_at: Time.current)
    @task = @project.tasks.create!(title: "Set out serving spoons")
    @slot = @project.slots.create!(date: "2027-02-15", label: "Bring dessert", capacity: 2)
  end

  test "a Team member cannot write to an archived Project" do
    sign_in_as_volunteer

    assert_no_difference [ "Task.count", "Comment.count", "Message.count", "DocItem.count", "SlotClaim.count" ] do
      post claim_project_task_path(@project, @task)
      post project_comments_path(@project), params: { comment: { commentable_type: "Task", commentable_id: @task.id, body: "Late" } }
      post project_messages_path(@project), params: { message: { body: "Late news" } }
      post project_doc_items_path(@project), params: { doc_item: { kind: "document", title: "Late", body: "Late" } }
      post project_slot_claim_path(@project, @slot)
    end

    assert_nil @task.reload.assignee_id
  end

  test "a non-Owner Leader cannot create Tasks on an archived Project" do
    sign_in_as(:other_leader)

    assert_no_difference "Task.count" do
      post project_tasks_path(@project), params: { task: { title: "Nope" } }
    end
  end

  test "the Owner and Admins can still write to an archived Project" do
    sign_in_as_leader
    assert_difference "Task.count", 1 do
      post project_tasks_path(@project), params: { task: { title: "Owner task" } }
    end

    sign_in_as_admin
    assert_difference "Task.count", 1 do
      post project_tasks_path(@project), params: { task: { title: "Admin task" } }
    end
  end

  test "archived Projects send no email notifications but still record them" do
    volunteer = people(:volunteer)

    assert_no_enqueued_emails do
      assert_difference -> { volunteer.notifications.count }, 1 do
        Notifier.notify(recipient: volunteer, kind: "task_assigned", notifiable: @task, actor: people(:leader))
      end
    end

    @project.update!(archived_at: nil)

    assert_enqueued_emails 1 do
      Notifier.notify(recipient: volunteer, kind: "task_assigned", notifiable: @task, actor: people(:leader))
    end
  end

  test "an invitee cannot accept an Invitation after the Project is archived but may decline" do
    @project.update!(archived_at: nil)
    invitee = people(:other_volunteer)
    invitation = @project.organization.invitations.create!(project: @project, person: invitee, inviter: people(:leader), role: "volunteer")
    token = invitation.generate_token_for(:access)
    @project.update!(archived_at: Time.current)
    sign_in_as(invitee)

    assert_no_difference "Membership.count" do
      patch accept_invitation_path(token)
    end
    assert_response :not_found
    assert_predicate invitation.reload, :pending?

    patch decline_invitation_path(token)
    assert_redirected_to home_path
  end

  test "the Owner cannot invite to an archived Project" do
    sign_in_as_leader

    assert_no_difference "Invitation.count" do
      post project_invitations_path(@project), params: { invitation: { person_id: people(:other_volunteer).id, role: "volunteer" } }
    end
    assert_response :not_found
  end

  test "an invitation email queued before archiving is not delivered" do
    @project.update!(archived_at: nil)
    invitation = @project.organization.invitations.create!(project: @project, person: people(:other_volunteer), inviter: people(:leader), role: "volunteer")
    InvitationMailer.invitation(invitation).deliver_later
    @project.update!(archived_at: Time.current)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      perform_enqueued_jobs
    end
  end
end
