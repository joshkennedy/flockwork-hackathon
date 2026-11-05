require "test_helper"

class NotificationsTest < ActionDispatch::IntegrationTest
  test "an Invitation creates an in-app notification and sends the existing invitation email" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    ActionMailer::Base.deliveries.clear

    assert_difference -> { Notification.count }, 1 do
      assert_emails 1 do
        perform_enqueued_jobs do
          post project_invitations_path(project), params: {
            invitation: { person_id: invitee.id, role: "volunteer" }
          }
        end
      end
    end

    notification = invitee.notifications.last!
    assert_equal "invitation", notification.kind
    assert_equal invitee, notification.recipient
    assert_equal leader, notification.actor
    assert_equal invitee.invitations.find_by!(project: project), notification.notifiable
  end

  test "turning Invitation email off keeps the in-app notification without sending email" do
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    invitee.update!(email_preferences: { "invitation" => false })
    ActionMailer::Base.deliveries.clear

    assert_difference -> { invitee.notifications.where(kind: "invitation").count }, 1 do
      assert_no_emails do
        perform_enqueued_jobs do
          post project_invitations_path(project), params: {
            invitation: { person_id: invitee.id, role: "volunteer" }
          }
        end
      end
    end
  end

  test "a Task assigned by a Leader creates a notification and sends email by default" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    assignee = people(:volunteer)
    ActionMailer::Base.deliveries.clear

    assert_difference -> { Notification.count }, 1 do
      assert_emails 1 do
        perform_enqueued_jobs do
          post project_tasks_path(project), params: {
            task: { title: "Set out water pitchers", assignee_id: assignee.id }
          }
        end
      end
    end

    task = project.tasks.find_by!(title: "Set out water pitchers")
    notification = assignee.notifications.last!
    assert_equal "task_assigned", notification.kind
    assert_equal assignee, notification.recipient
    assert_equal leader, notification.actor
    assert_equal task, notification.notifiable
  end

  test "changing a Task to a new assignee notifies that Person" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    assignee = people(:volunteer)
    task = project.tasks.create!(title: "Stack the chairs")
    ActionMailer::Base.deliveries.clear

    assert_difference -> { assignee.notifications.where(kind: "task_assigned", notifiable: task).count }, 1 do
      assert_emails 1 do
        perform_enqueued_jobs do
          patch project_task_path(project, task), params: {
            task: { title: task.title, assignee_id: assignee.id }
          }
        end
      end
    end

    assert_equal leader, assignee.notifications.last!.actor
  end

  test "self-claiming a Task does not create a notification" do
    person = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Carry the trays")
    ActionMailer::Base.deliveries.clear

    assert_no_difference -> { Notification.count } do
      assert_no_emails do
        perform_enqueued_jobs do
          post claim_project_task_path(project, task)
        end
      end
    end

    assert_equal person, task.reload.assignee
  end

  test "a Leader assigning a Task to themselves is not notified" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    ActionMailer::Base.deliveries.clear

    assert_no_difference -> { Notification.count } do
      assert_no_emails do
        perform_enqueued_jobs do
          post project_tasks_path(project), params: {
            task: { title: "Open the building", assignee_id: leader.id }
          }
        end
      end
    end

    assert_equal leader, project.tasks.find_by!(title: "Open the building").assignee
  end

  test "an at-mention creates a notification and sends email by default" do
    author = sign_in_as_volunteer
    project = projects(:community_meal)
    mentioned_person = people(:other_leader)
    task = project.tasks.create!(title: "Confirm the serving plan")
    ActionMailer::Base.deliveries.clear

    assert_difference -> { Notification.count }, 1 do
      assert_emails 1 do
        perform_enqueued_jobs do
          post project_comments_path(project), params: {
            comment: {
              commentable_type: "Task",
              commentable_id: task.id,
              body: "Can you check this, @[Lucy Leader](person:#{mentioned_person.id})?"
            }
          }
        end
      end
    end

    mention = task.comments.last!.mentions.find_by!(person: mentioned_person)
    notification = mentioned_person.notifications.last!
    assert_equal "mention", notification.kind
    assert_equal mentioned_person, notification.recipient
    assert_equal author, notification.actor
    assert_equal mention, notification.notifiable
  end

  test "a reply notifies every follower except the author without emailing by default" do
    author = sign_in_as_volunteer
    project = projects(:community_meal)
    follower = people(:leader)
    task = project.tasks.create!(title: "Arrange the serving line")
    task.follows.create!(person: follower)
    ActionMailer::Base.deliveries.clear

    assert_difference -> { Notification.count }, 1 do
      assert_no_emails do
        perform_enqueued_jobs do
          post project_comments_path(project), params: {
            comment: {
              commentable_type: "Task",
              commentable_id: task.id,
              body: "The serving line is ready."
            }
          }
        end
      end
    end

    comment = task.comments.last!
    notification = follower.notifications.last!
    assert_equal "followed_reply", notification.kind
    assert_equal follower, notification.recipient
    assert_equal author, notification.actor
    assert_equal comment, notification.notifiable
    assert_not author.notifications.exists?(kind: "followed_reply", notifiable: comment)
  end

  test "turning mention email off still creates the in-app notification" do
    mentioned_person = sign_in_as(:other_leader)

    patch profile_path, params: {
      person: {
        name: mentioned_person.name,
        phone: mentioned_person.phone,
        email_preferences: { "mention" => "0" }
      }
    }

    assert_redirected_to home_path
    assert_not mentioned_person.reload.email_for?("mention")

    delete session_path
    author = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Check the place settings")
    ActionMailer::Base.deliveries.clear

    assert_difference -> { mentioned_person.notifications.count }, 1 do
      assert_no_emails do
        perform_enqueued_jobs do
          post project_comments_path(project), params: {
            comment: {
              commentable_type: "Task",
              commentable_id: task.id,
              body: "Please check this, @[Lucy Leader](person:#{mentioned_person.id})."
            }
          }
        end
      end
    end

    notification = mentioned_person.notifications.last!
    assert_equal "mention", notification.kind
    assert_equal author, notification.actor
  end

  test "opting in to followed replies sends email" do
    follower = sign_in_as_leader

    patch profile_path, params: {
      person: {
        name: follower.name,
        phone: follower.phone,
        email_preferences: { "followed_reply" => "1" }
      }
    }
    assert follower.reload.email_for?("followed_reply")

    delete session_path
    sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Lay out the buffet")
    task.follows.create!(person: follower)
    ActionMailer::Base.deliveries.clear

    assert_difference -> { follower.notifications.count }, 1 do
      assert_emails 1 do
        perform_enqueued_jobs do
          post project_comments_path(project), params: {
            comment: {
              commentable_type: "Task",
              commentable_id: task.id,
              body: "The buffet is ready."
            }
          }
        end
      end
    end

    assert_equal "followed_reply", follower.notifications.last!.kind
  end

  test "the profile form shows every email preference with registry defaults" do
    person = sign_in_as_volunteer

    get edit_profile_path

    assert_response :success
    assert_select "fieldset legend", "Notification delivery"
    assert_select "input[type='checkbox'][name='person[email_preferences][invitation]'][checked]", count: 1
    assert_select "input[type='checkbox'][name='person[email_preferences][task_assigned]'][checked]", count: 1
    assert_select "input[type='checkbox'][name='person[email_preferences][mention]'][checked]", count: 1
    assert_select "input[type='checkbox'][name='person[email_preferences][slot_reminder]'][checked]", count: 1
    assert_select "input[type='checkbox'][name='person[email_preferences][followed_reply]'][checked]", count: 0
    assert_select "input[type='checkbox'][name='person[email_preferences][team_departure]'][checked]", count: 1
    assert_select "th[scope='row']", text: "Replies on things you follow"
  end

  test "the Slot reminder job notifies and emails each claimer only once" do
    person = people(:volunteer)
    project = projects(:community_meal)
    no_email_person = project.organization.people.create!(name: "Nora No Email")
    project.memberships.create!(person: no_email_person, role: :volunteer)
    ActionMailer::Base.deliveries.clear

    travel_to Time.zone.local(2027, 2, 10, 12, 0, 0) do
      slot = project.slots.create!(date: Date.tomorrow, label: "Bring the main dish", capacity: 2)
      slot.slot_claims.create!(person: person)
      slot.slot_claims.create!(person: no_email_person)

      assert_difference -> { person.notifications.where(kind: "slot_reminder", notifiable: slot).count }, 1 do
        assert_emails 1 do
          perform_enqueued_jobs do
            SlotReminderJob.perform_now
            SlotReminderJob.perform_now
          end
        end
      end

      notification = person.notifications.find_by!(kind: "slot_reminder", notifiable: slot)
      assert_equal person, notification.recipient
      assert_nil notification.actor
      assert_equal 1, no_email_person.notifications.where(kind: "slot_reminder", notifiable: slot).count
    end
  end

  test "leaving a Team notifies every Leader except the departing Person" do
    departing_person = sign_in_as_volunteer
    project = projects(:community_meal)
    membership = project.memberships.find_by!(person: departing_person)
    leaders = [ people(:leader), people(:other_leader) ]
    ActionMailer::Base.deliveries.clear

    assert_difference -> { Notification.where(kind: "team_departure", notifiable: project).count }, 2 do
      assert_emails 2 do
        perform_enqueued_jobs do
          delete project_membership_path(project, membership)
        end
      end
    end

    notifications = Notification.where(kind: "team_departure", notifiable: project).order(:recipient_id)
    assert_equal leaders.map(&:id).sort, notifications.pluck(:recipient_id).sort
    assert notifications.all? { |notification| notification.actor == departing_person }
    assert_not departing_person.notifications.exists?(kind: "team_departure", notifiable: project)
  end

  test "removing a Team member notifies the other Leaders but not the actor" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    membership = project.memberships.find_by!(person: people(:volunteer))
    other_leader = people(:other_leader)
    ActionMailer::Base.deliveries.clear

    assert_difference -> { Notification.where(kind: "team_departure", notifiable: project).count }, 1 do
      assert_emails 1 do
        perform_enqueued_jobs do
          delete project_membership_path(project, membership)
        end
      end
    end

    notification = Notification.find_by!(kind: "team_departure", notifiable: project)
    assert_equal other_leader, notification.recipient
    assert_equal leader, notification.actor
    assert_not leader.notifications.exists?(kind: "team_departure", notifiable: project)
  end

  test "Notifications splits Needs you from the rest, grouped by Project, and the bell counts only Needs you" do
    person = sign_in_as_volunteer
    project = projects(:community_meal)
    welcome_team = project.organization.projects.create!(name: "Welcome Team", owner: people(:leader))
    welcome_team.memberships.create!(person: person, role: :volunteer)
    assigned = Notifier.notify(
      recipient: person,
      kind: "task_assigned",
      notifiable: project.tasks.create!(title: "Set out chairs", assignee: person),
      actor: people(:leader),
      email: false
    )
    slot = project.slots.create!(date: Date.tomorrow, label: "Bring dessert", capacity: 2)
    slot.slot_claims.create!(person: person)
    claimed = Notifier.notify(recipient: person, kind: "slot_reminder", notifiable: slot, email: false)
    claimed.update!(read_at: Time.current)
    mention = Notifier.notify(recipient: person, kind: "mention", notifiable: project, actor: people(:leader), email: false)
    mention.update!(read_at: Time.current)
    departure = Notifier.notify(recipient: person, kind: "team_departure", notifiable: welcome_team, actor: people(:leader), email: false)
    reply = Notifier.notify(recipient: person, kind: "followed_reply", notifiable: project, actor: people(:leader), email: false)

    get notifications_path

    assert_response :success
    needs_you = "section[aria-labelledby='needs-you-heading']"
    for_information = "section[aria-labelledby='for-information-heading']"
    assert_select "#{needs_you} [data-notification-id]", count: 2
    assert_select "#{needs_you} [data-notification-id='#{assigned.id}']"
    assert_select "#{needs_you} [data-notification-id='#{claimed.id}']"
    assert_select "#{for_information} [data-notification-id]", count: 3
    assert_select "#{for_information} h3 a", text: "Community Meal"
    assert_select "#{for_information} h3 a", text: "Welcome Team"
    assert_select "#{for_information} [data-notification-id='#{mention.id}']"
    assert_select "#{for_information} [data-notification-id='#{departure.id}'] form[action='#{mark_read_notification_path(departure)}']"
    assert_select "#{for_information} [data-notification-id='#{reply.id}']"
    assert_select "a[href='#{notifications_path}'][aria-label='Notifications, 1 unread']", minimum: 1

    patch mark_read_notification_path(departure)

    assert_redirected_to notifications_path
    assert_not_nil departure.reload.read_at
    get notifications_path
    assert_select "a[href='#{notifications_path}'][aria-label='Notifications, 1 unread']", minimum: 1

    patch mark_read_notification_path(assigned)
    get notifications_path
    assert_select "a[href='#{notifications_path}'][aria-label='Notifications']", minimum: 1
    assert_select "#{needs_you} [data-notification-id='#{assigned.id}'] form[action='#{mark_read_notification_path(assigned)}']", count: 0

    patch mark_all_read_notifications_path

    assert_redirected_to notifications_path
    assert_not_nil reply.reload.read_at
  end

  test "Needs you rows offer the action that resolves them" do
    person = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Set out chairs", assignee: person)
    Notifier.notify(recipient: person, kind: "task_assigned", notifiable: task, actor: people(:leader), email: false)
    welcome_team = project.organization.projects.create!(name: "Welcome Team", owner: people(:leader))
    invitation = project.organization.invitations.create!(project: welcome_team, person: person, inviter: people(:leader), role: :volunteer)
    Notifier.notify(recipient: person, kind: "invitation", notifiable: invitation, actor: people(:leader), email: false)

    get notifications_path

    assert_select "form[action='#{mark_done_project_task_path(project, task)}']", text: /Mark Done/
    invitation_links = css_select("a[href^='/invitations/']")
    assert_equal 1, invitation_links.count
    invitation_link = invitation_links.first
    assert_equal "Respond", invitation_link.text.strip
    token = invitation_link["href"][%r{/invitations/(\S+)}, 1]
    assert_equal invitation, Invitation.find_by_token_for(:access, token)
  end

  test "an accepted Invitation remains listed for information" do
    inviter = sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)

    post project_invitations_path(project), params: {
      invitation: { person_id: invitee.id, role: "volunteer" }
    }
    invitation = inviter.organization.invitations.find_by!(project: project, person: invitee)
    notification = invitee.notifications.find_by!(kind: "invitation", notifiable: invitation)
    token = invitation.generate_token_for(:access)

    delete session_path
    sign_in_token = invitee.generate_token_for(:sign_in)
    get sign_in_link_path(sign_in_token)
    post sign_in_link_path(sign_in_token)
    get invitation_path(token)
    patch accept_invitation_path(token)
    get notifications_path

    assert_predicate invitation.reload, :accepted?
    assert_select "section[aria-labelledby='needs-you-heading'] [data-notification-id='#{notification.id}']", count: 0
    assert_select "section[aria-labelledby='for-information-heading'] [data-notification-id='#{notification.id}']"
    assert_select "[data-notification-id='#{notification.id}'] a > span:last-child", "invited you to join Community Meal."
  end

  test "a Person with nothing to act on or report sees warm empty states" do
    sign_in_as_volunteer

    get notifications_path

    assert_response :success
    assert_select "section[aria-labelledby='needs-you-heading'] p", text: /You’re all caught up/
    assert_select "section[aria-labelledby='for-information-heading'] p", text: /Nothing else to report/
    assert_select "[data-notification-id]", count: 0
  end

  test "a Person gets 404 for another Person's notification" do
    sign_in_as_volunteer
    other_notification = Notifier.notify(
      recipient: people(:other_leader),
      kind: "task_assigned",
      notifiable: projects(:community_meal).tasks.create!(title: "Lock the kitchen"),
      actor: people(:leader),
      email: false
    )

    patch mark_read_notification_path(other_notification)

    assert_response :not_found
    assert_nil other_notification.reload.read_at

    get notifications_path
    assert_response :success
    assert_no_match "Lock the kitchen", response.body
  end

  test "the notification list handles a missing actor" do
    person = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Fold the tablecloths", assignee: person)
    Notifier.notify(
      recipient: person,
      kind: "task_assigned",
      notifiable: task,
      email: false
    )

    get notifications_path

    assert_response :success
    assert_select "a[href='#{project_path(project)}']", "Someone assigned you “Fold the tablecloths”."
  end

  test "deleting a notified item removes its notification" do
    person = sign_in_as_leader
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Remove the folding tables")
    notification = Notifier.notify(
      recipient: person,
      kind: "task_assigned",
      notifiable: task,
      actor: people(:other_leader),
      email: false
    )

    assert_difference -> { Notification.where(id: notification.id).count }, -1 do
      delete project_task_path(project, task)
    end

    get notifications_path
    assert_response :success
    assert_no_match "Remove the folding tables", response.body
  end
end
