require "test_helper"

class DirectoryManagementTest < ActionDispatch::IntegrationTest
  test "Admin adds a Person with email and they appear in the directory" do
    sign_in_as_admin

    assert_difference -> { organizations(:st_example).people.count }, 1 do
      post people_path, params: {
        person: { name: "Pat Person", email: "pat@st-example.test", phone: "555-0100" }
      }
    end

    assert_redirected_to people_path
    follow_redirect!
    assert_select "li", /Pat Person/
    assert_no_match "pat@st-example.test", response.body
  end

  test "Add Person opens in the directory slideout and direct URLs remain full-page fallbacks" do
    sign_in_as_admin

    get people_path
    assert_select "a[href=?][data-action='slideout#open'][data-slideout-title-param='Add Person']", new_person_path
    assert_select "dialog.slideout turbo-frame#person-form[data-slideout-target='frame']"

    get new_person_path
    assert_select "turbo-frame#person-form form[data-turbo-frame='_top']"

    get new_person_path, headers: { "Turbo-Frame" => "person-form" }
    assert_select "turbo-frame#person-form form"
    assert_select "turbo-frame#person-form form[data-turbo-frame='_top']", count: 0
  end

  test "Admin adds a Person without email; they show as unable to sign in and cannot receive a link" do
    sign_in_as_admin

    post people_path, params: { person: { name: "No Email Pat" } }

    assert_redirected_to people_path
    person = organizations(:st_example).people.find_by!(name: "No Email Pat")
    assert_not person.can_sign_in?

    follow_redirect!
    assert_select "li", /No Email Pat/
    assert_select "li", /Can't sign in/

    delete session_path
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path, params: { email: "pat@st-example.test" }
      end
    end
  end

  test "a blank Person name returns an in-page error instead of relying on browser validation" do
    sign_in_as_admin

    assert_no_difference "Person.count" do
      post people_path, params: { person: { name: "", email: "blank-name@example.test" } }
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: "Name can't be blank"
    assert_select "input[name='person[name]'][required]", count: 0
  end

  test "saving from the Edit details slideout refreshes the person page" do
    sign_in_as_admin

    patch person_path(people(:volunteer)), params: { person: { name: "Victor Volunteer" } }, headers: { "Turbo-Frame" => "edit-person" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(<turbo-stream action="refresh">)
    assert_equal "Victor Volunteer", people(:volunteer).reload.name
  end

  test "Admin edits another Person's name, email and phone" do
    sign_in_as_admin

    patch person_path(people(:volunteer)), params: {
      person: { name: "Victor Volunteer", email: "victor@st-example.test", phone: "555-0199", admin: "0" }
    }

    assert_redirected_to person_path(people(:volunteer))
    people(:volunteer).reload
    assert_equal "Victor Volunteer", people(:volunteer).name
    assert_equal "vic@st-example.test", people(:volunteer).email
    assert_equal "victor@st-example.test", people(:volunteer).pending_email
    assert_equal "555-0199", people(:volunteer).phone
  end

  test "Admin grants and revokes Admin on another Person" do
    sign_in_as_admin

    patch person_path(people(:leader)), params: {
      person: { name: people(:leader).name, email: people(:leader).email, admin: "1" }
    }

    assert people(:leader).reload.admin?

    patch person_path(people(:leader)), params: {
      person: { name: people(:leader).name, email: people(:leader).email, admin: "0" }
    }

    assert_not people(:leader).reload.admin?
  end

  test "the last Admin cannot revoke their own Admin role" do
    sign_in_as_admin

    patch person_path(people(:admin)), params: {
      person: { name: people(:admin).name, email: people(:admin).email, admin: "0" }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Admin can’t be removed until another person is an Admin/
    assert people(:admin).reload.admin?
  end

  test "non-Admin gets 404 on directory management" do
    sign_in_as_volunteer

    get people_path
    assert_response :not_found

    get new_person_path
    assert_response :not_found

    post people_path, params: { person: { name: "Sneak" } }
    assert_response :not_found

    get edit_person_path(people(:leader))
    assert_response :not_found

    delete person_path(people(:leader))
    assert_response :not_found
  end

  test "Admin soft-removes a Person while preserving authorship and clearing participation" do
    sign_in_as_admin
    admin = people(:admin)
    person = organizations(:st_example).people.create!(name: "Remove Me", email: "remove@st-example.test")
    project = projects(:community_meal)
    membership = project.memberships.create!(person:, role: :leader)
    slot = project.slots.create!(date: Date.current + 3, label: "Removed claim")
    claim = slot.slot_claims.create!(person:)
    task = project.tasks.create!(title: "Removed assignment", assignee: person)
    notification = Notification.create!(recipient: person, kind: :task_assigned, notifiable: task, actor: admin)
    owned_project = organizations(:st_example).projects.create!(name: "Preserved Project", owner: person)
    message = project.messages.create!(author: person, body: "Keep this update")
    comment = message.comments.create!(author: person, body: "Keep this reply")
    note = project.notes.create!(organization: organizations(:st_example), author: person, visibility: :team, body: "Keep this note")
    doc_item = project.doc_items.create!(author: person, kind: :link, title: "Keep this link", url: "https://example.com")
    budget_line = project.budget_lines.create!(kind: :purchase, description: "Keep this cost", responsible_person: person)
    recurrence = project.create_project_recurrence!(creator: person, frequency: :weekly, anchor_on: Date.current, enabled: false)
    planner_session = project.planner_sessions.create!(started_by: person, description: "Keep planning", flow_version: 3, planning_kind: "other")
    session = person.sessions.create!(auth_method: "magic_link")
    follow = message.follows.find_by!(person:)
    recipient = projects(:building_cleanup).recipients.create!(person:)
    invitation = organizations(:st_example).invitations.create!(project: projects(:building_cleanup), person:, inviter: admin, role: :volunteer)
    unavailable = person.unavailabilities.create!(organization: organizations(:st_example), starts_on: Date.current, ends_on: Date.current + 2)

    delete person_path(person)

    assert_redirected_to people_path
    assert Person.exists?(person.id)
    assert_predicate person.reload.removed_at, :present?
    assert_not Membership.exists?(membership.id)
    assert_not SlotClaim.exists?(claim.id)
    assert_nil task.reload.assignee
    assert_not Notification.exists?(notification.id)
    assert_not Session.exists?(session.id)
    assert_not Follow.exists?(follow.id)
    assert_not Recipient.exists?(recipient.id)
    assert_not Invitation.exists?(invitation.id)
    assert_not Unavailability.exists?(unavailable.id)
    assert_equal admin, owned_project.reload.owner
    assert_equal admin, recurrence.reload.creator
    assert_equal admin, planner_session.reload.started_by
    assert_equal person, message.reload.author
    assert_equal person, comment.reload.author
    assert_equal person, note.reload.author
    assert_equal person, doc_item.reload.author
    assert_equal "Remove Me", message.author.name
    assert_nil budget_line.reload.responsible_person
  end

  test "Admin cannot remove themselves" do
    sign_in_as_admin

    assert_no_difference "Person.count" do
      delete person_path(people(:admin))
    end

    assert_redirected_to person_path(people(:admin))
    assert_equal "You can’t remove yourself from the directory.", flash[:alert]
  end

  test "removed People stay out of every people finder and notification delivery" do
    organization = organizations(:st_example)
    person = organization.people.create!(name: "Hidden Former Member", email: "hidden-former@example.test")
    project = projects(:community_meal)
    project.memberships.create!(person:, role: :volunteer)
    person.update!(removed_at: Time.current)
    sign_in_as_admin

    get people_path, params: { query: "Hidden Former" }
    assert_no_match person.name, response.body

    get search_path, params: { query: "Hidden Former" }
    assert_select "section[aria-label=People]", count: 0

    get team_project_path(projects(:building_cleanup)), params: { query: "Hidden Former" }
    assert_no_match person.name, response.body

    get mentionable_people_project_path(project), params: { q: "Hidden Former" }, as: :json
    assert_empty response.parsed_body.fetch("people")

    assert_not_includes Oversight.involvement_list(organization, Time.current.year).map { |entry| entry.fetch(:person) }, person

    task = project.tasks.create!(title: "Do not notify")
    assert_no_difference "Notification.count" do
      assert_nil Notifier.notify(recipient: person, kind: "task_assigned", notifiable: task, actor: people(:admin))
    end
  end

  test "adding the same email restores a removed Person" do
    person = organizations(:st_example).people.create!(
      name: "Former Name",
      email: "restore-me@st-example.test",
      removed_at: Time.current
    )
    sign_in_as_admin

    assert_no_difference "Person.count" do
      post people_path, params: {
        person: { name: "Restored Name", email: "restore-me@st-example.test", phone: "202-555-0142" }
      }
    end

    assert_redirected_to people_path
    assert_predicate person.reload, :active?
    assert_equal "Restored Name", person.name
    assert_equal "202-555-0142", person.phone

    person.update!(removed_at: Time.current)
    assert_no_difference "Person.count" do
      assert_difference "Invitation.count", 1 do
        post project_invitations_path(projects(:building_cleanup)), params: {
          invitation: { name: "Ignored Replacement Name", email: person.email, role: "volunteer" }
        }
      end
    end
    assert_predicate person.reload, :active?
  end

  test "a Person edits their own name and phone" do
    sign_in_as_volunteer

    patch profile_path, params: {
      person: { name: "Vic Updated", phone: "555-7777" }
    }

    assert_redirected_to settings_path(anchor: "settings-details")
    people(:volunteer).reload
    assert_equal "Vic Updated", people(:volunteer).name
    assert_equal "555-7777", people(:volunteer).phone
  end

  test "forged admin param on profile update does not grant Admin" do
    sign_in_as_volunteer

    patch profile_path, params: {
      person: { name: people(:volunteer).name, phone: "", admin: "1", email: "hacker@example.com" }
    }

    assert_redirected_to settings_path(anchor: "settings-details")
    people(:volunteer).reload
    assert_not people(:volunteer).admin?
    assert_equal "vic@st-example.test", people(:volunteer).email
  end

  test "duplicate email in the same Organization is rejected on the form" do
    sign_in_as_admin

    post people_path, params: {
      person: { name: "Duplicate", email: people(:leader).email }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Email is already used by someone else in this church/
  end

  test "the same email in another Organization is allowed" do
    sign_in_as_outsider

    assert_difference -> { organizations(:outsider_church).people.count }, 1 do
      post people_path, params: {
        person: { name: "Shared Email", email: people(:admin).email }
      }
    end

    assert_redirected_to people_path
  end

  test "organization home links to People for Admins and to My profile for everyone" do
    sign_in_as_admin
    get home_path
    assert_select "a[href=?]", people_path, text: "People"
    assert_select "a[href=?]", profile_path

    delete session_path
    sign_in_as_volunteer
    get home_path
    assert_select "a[href=?]", people_path, count: 0
    assert_select "a[href=?]", profile_path
  end

  test "the directory lists People sorted by name" do
    sign_in_as_admin

    get people_path

    assert_response :success
    names = css_select("turbo-frame#people-results li a.font-semibold").map { |link| link.text.strip }
    assert_equal names.sort, names
  end

  test "each directory row links the Person's name to their person page" do
    sign_in_as_admin

    get people_path

    assert_select "a[href=?]", person_path(people(:volunteer)), text: people(:volunteer).name
    assert_select "a", text: "Edit", count: 0
  end

  test "searching the directory by name narrows the list" do
    sign_in_as_admin

    get people_path, params: { query: "vic" }

    assert_response :success
    assert_select "turbo-frame#people-results a", text: people(:volunteer).name
    assert_select "turbo-frame#people-results a", text: people(:leader).name, count: 0
  end

  test "a search with no match says so and offers to clear it" do
    sign_in_as_admin

    get people_path, params: { query: "zzz no such person" }

    assert_select "turbo-frame#people-results p", text: /No people match "zzz no such person"/
    assert_select "turbo-frame#people-results a[href=?]", people_path, text: "Clear search"
  end

  test "the CSV file input has a visible label" do
    sign_in_as_admin

    get new_people_csv_import_path

    assert_select "label[for=?]", "csv_file", text: "CSV file"
    assert_select "input#csv_file[type=file]"
  end

  test "the Admin checkbox says what Admins can do" do
    sign_in_as_admin

    get edit_person_path(people(:leader))

    assert_select "fieldset", text: /Skills/ do
      assert_select "label", text: "Administration"
      assert_select "label", text: /^Admin$/i, count: 0
    end
    assert_select "p", text: "Admins can manage People and Settings."
  end
end
