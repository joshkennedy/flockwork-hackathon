require "test_helper"

class CommentsMentionsFollowsTest < ActionDispatch::IntegrationTest
  test "a Team member comments on a Task and follows it" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Set out serving spoons")

    assert_difference "Comment.count", 1 do
      post project_comments_path(project), params: {
        comment: {
          commentable_type: "Task",
          commentable_id: task.id,
          body: "I can handle this."
        }
      }
    end

    assert_redirected_to project_path(project)
    comment = task.comments.last!
    assert_equal member, comment.author
    assert_equal "I can handle this.", comment.body.to_plain_text
    assert task.follows.exists?(person: member)
  end

  test "a Team member comments on each remaining Tool item type" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    schedule_item = schedule_items(:community_meal_lunch)
    slot = project.slots.create!(date: "2027-02-12", label: "Serve dessert")
    budget_line = budget_lines(:community_meal_supplies)
    doc_item = project.doc_items.create!(
      author: people(:leader),
      kind: :document,
      title: "Kitchen plan",
      body: "Prep notes"
    )
    list_row = lists(:room_assignments).rows.create!

    post project_comments_path(project), params: {
      comment: {
        commentable_type: "ScheduleItem",
        commentable_id: schedule_item.id,
        body: "Schedule comment"
      }
    }
    assert_redirected_to project_path(project)

    post project_comments_path(project), params: {
      comment: { commentable_type: "Slot", commentable_id: slot.id, body: "Slot comment" }
    }
    assert_redirected_to project_path(project)

    post project_comments_path(project), params: {
      comment: {
        commentable_type: "BudgetLine",
        commentable_id: budget_line.id,
        body: "Budget comment"
      }
    }
    assert_redirected_to project_path(project)

    post project_comments_path(project), params: {
      comment: {
        commentable_type: "DocItem",
        commentable_id: doc_item.id,
        body: "Document comment"
      }
    }
    assert_redirected_to project_path(project)

    post project_comments_path(project), params: {
      comment: {
        commentable_type: "ListRow",
        commentable_id: list_row.id,
        body: "List row comment"
      }
    }
    assert_redirected_to project_path(project)

    assert_equal "Schedule comment", schedule_item.comments.last!.body.to_plain_text
    assert_equal "Slot comment", slot.comments.last!.body.to_plain_text
    assert_equal "Budget comment", budget_line.comments.last!.body.to_plain_text
    assert_equal "Document comment", doc_item.comments.last!.body.to_plain_text
    assert_equal "List row comment", list_row.comments.last!.body.to_plain_text
  end

  test "mentioning a Person who can see the Project records a Mention and Follow" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Confirm the room layout")
    mentioned_person = people(:other_leader)

    post project_comments_path(project), params: {
      comment: {
        commentable_type: "Task",
        commentable_id: task.id,
        body: "Can you check this, @[Lucy Leader](person:#{mentioned_person.id})?"
      }
    }

    comment = task.comments.last!
    assert_redirected_to project_path(project)
    assert comment.mentions.exists?(person: mentioned_person)
    assert task.follows.exists?(person: mentioned_person)
  end

  test "mentioning a Person who cannot see the Project records nothing for them" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Count the place settings")
    non_member = people(:other_volunteer)

    post project_comments_path(project), params: {
      comment: {
        commentable_type: "Task",
        commentable_id: task.id,
        body: "Please help, @[Vera Volunteer](person:#{non_member.id})."
      }
    }

    comment = task.comments.last!
    assert_redirected_to project_path(project)
    assert_not comment.mentions.exists?(person: non_member)
    assert_not task.follows.exists?(person: non_member)
  end

  test "commenting and mentioning the author creates one idempotent Follow" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Check the serving line")

    post project_comments_path(project), params: {
      comment: {
        commentable_type: "Task",
        commentable_id: task.id,
        body: "My note, @[Vic Volunteer](person:#{member.id})."
      }
    }

    assert_redirected_to project_path(project)
    assert_equal 1, task.follows.where(person: member).count
  end

  test "message bodies record mentions and follow the message" do
    author = sign_in_as_volunteer
    project = projects(:community_meal)
    mentioned_person = people(:other_leader)

    post project_messages_path(project), params: {
      message: { body: "Review this, @[Lucy Leader](person:#{mentioned_person.id})." }
    }

    message = project.messages.last!
    assert_redirected_to project_path(project)
    assert message.mentions.exists?(person: mentioned_person)
    assert message.follows.exists?(person: mentioned_person)
    assert message.follows.exists?(person: author)
  end

  test "the mention picker returns only People who can see the Project" do
    sign_in_as_leader
    project = projects(:community_meal)

    get mentionable_people_project_path(project), params: { q: "" }, as: :json

    assert_response :success
    names = response.parsed_body.fetch("people").pluck("name")
    assert_equal [ "Ada Admin", "Leo Leader", "Lucy Leader", "Vic Volunteer" ], names
    assert_not_includes names, "Vera Volunteer"
    assert_not_includes names, "Olive Outsider"
  end

  test "a Person unfollows an item they commented on" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Refill the water pitchers")

    post project_comments_path(project), params: {
      comment: { commentable_type: "Task", commentable_id: task.id, body: "I will do this." }
    }

    follow = task.follows.find_by!(person: member)

    assert_difference "Follow.count", -1 do
      delete project_follow_path(project, follow)
    end

    assert_redirected_to project_path(project)
    assert_not task.follows.exists?(person: member)
  end

  test "a non-member gets 404 posting a comment" do
    sign_in_as(:other_volunteer)
    project = projects(:community_meal)
    task = project.tasks.create!(title: "Private Team Task")

    assert_no_difference "Comment.count" do
      post project_comments_path(project), params: {
        comment: { commentable_type: "Task", commentable_id: task.id, body: "Intruding" }
      }
    end

    assert_response :not_found
  end

  test "each Tool item renders a compact comments disclosure" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: Project::TOOLS)
    task = project.tasks.create!(title: "Comments Task")
    schedule_item = schedule_items(:community_meal_arrival)
    slot = project.slots.create!(date: "2027-02-12", label: "Comments Slot")
    budget_line = budget_lines(:community_meal_venue)
    doc_item = project.doc_items.create!(
      author: member,
      kind: :document,
      title: "Comments Document",
      body: "Document body"
    )
    list_row = lists(:room_assignments).rows.create!
    message = project.messages.create!(author: member, body: "Existing message thread")

    task.comments.create!(author: member, body: "Task thread")
    schedule_item.comments.create!(author: member, body: "Schedule thread")
    slot.comments.create!(author: member, body: "Slot thread")
    budget_line.comments.create!(author: member, body: "Budget thread")
    doc_item.comments.create!(author: member, body: "Document thread")
    list_row.comments.create!(author: member, body: "List thread")

    get project_path(project)

    assert_response :success
    assert_select "details[data-commentable-type='Task'][data-commentable-id='#{task.id}'] summary", text: /1 Comment/
    assert_select "details[data-commentable-type='ScheduleItem'][data-commentable-id='#{schedule_item.id}'] summary", text: /1 Comment/
    assert_select "button[data-action='comment-thread#toggle']", text: /View 1 Comment/
    assert_select "section[data-commentable-type='Slot'][data-commentable-id='#{slot.id}'][hidden]"
    assert_select "details[data-commentable-type='BudgetLine'][data-commentable-id='#{budget_line.id}'] summary", text: /1 Comment/
    assert_select "details[data-commentable-type='DocItem'][data-commentable-id='#{doc_item.id}'] summary", text: /1 Comment/
    assert_select "details[data-commentable-type='ListRow'][data-commentable-id='#{list_row.id}'] summary", text: /1 Comment/
    assert_select "[data-message-id='#{message.id}']"
    assert_select "details[data-commentable-type='Message']", count: 0
    assert_select "[data-controller='mention-picker']", minimum: 6
    assert_select "section[aria-labelledby='tool-messages'] textarea[name='message[body]']"
    assert_select "section[aria-labelledby='tool-messages'] trix-editor", count: 0
  end

  test "an item with no comments shows an actionable Add Comment control" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])
    slot = project.slots.create!(date: "2027-02-12", label: "Quiet Slot")

    get project_path(project)

    assert_select "button[data-action='comment-thread#toggle']", text: /Add Comment/
    assert_select "section[data-commentable-type='Slot'][data-commentable-id='#{slot.id}'][hidden]"
    assert_select "li[data-controller='comment-thread'] > div > details.actions-menu summary svg", count: 1
    assert_no_match "No comments yet", response.body
  end
end
