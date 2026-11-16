require "test_helper"

class RecipientsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @project.update!(enabled_tools: @project.enabled_tools + [ "recipients" ])
  end

  test "a Leader adds a Recipient from the directory without changing Team membership" do
    sign_in_as_leader
    person = people(:recipient)

    assert_difference "Recipient.count", 1 do
      assert_no_difference "Membership.count" do
        post project_recipients_path(@project), params: { person_id: person.id }
      end
    end

    assert_redirected_to project_path(@project)
    follow_redirect!
    assert_select "section[aria-labelledby='tool-recipients'] li", text: /Rowan Recipient/
  end

  test "adding a Recipient turns on the Recipients Tool so the saved person stays visible" do
    sign_in_as_leader
    @project.update!(enabled_tools: @project.enabled_tools - [ "recipients" ])

    post project_recipients_path(@project), params: { person_id: people(:recipient).id }

    assert_redirected_to project_path(@project)
    assert_includes @project.reload.enabled_tools, "recipients"
    follow_redirect!
    assert_select "section[aria-labelledby='tool-recipients'] li", text: /Rowan Recipient/
  end

  test "a Person created through the recipients flow records the Leader and the directory says so" do
    sign_in_as_leader
    post project_recipients_path(@project), params: { person: { name: "Taylor Care", phone: "555-0100" } }
    post project_recipients_path(@project), params: { person_id: people(:recipient).id }

    assert_equal people(:leader), Person.find_by!(name: "Taylor Care").added_by
    assert_nil people(:recipient).reload.added_by

    delete session_path
    sign_in_as_admin
    get people_path

    assert_select "turbo-frame#people-results li", text: /Taylor Care/ do
      assert_select "p", text: "Added by Leo Leader"
    end
    assert_select "turbo-frame#people-results p", text: /Added by/, count: 1
  end

  test "a Leader creates a new Person without email as a Recipient" do
    sign_in_as_leader

    assert_difference [ "Person.count", "Recipient.count" ], 1 do
      assert_no_difference "Membership.count" do
        post project_recipients_path(@project), params: {
          person: { name: "Taylor Care", phone: "555-0100" }
        }
      end
    end

    new_person = people(:leader).organization.people.find_by!(name: "Taylor Care")
    assert_nil new_person.email
    assert_equal "555-0100", new_person.phone
    assert_redirected_to project_path(@project)
  end

  test "a Leader removes a Recipient but the Person remains in the directory" do
    sign_in_as_leader
    person = people(:recipient)
    post project_recipients_path(@project), params: { person_id: person.id }
    recipient = @project.recipients.find_by!(person: person)

    assert_difference "Recipient.count", -1 do
      assert_no_difference "Person.count" do
        delete project_recipient_path(@project, recipient)
      end
    end

    assert_redirected_to project_path(@project)
    assert Person.exists?(person.id)
  end

  test "Recipients never appear on the Team page" do
    sign_in_as_leader
    post project_recipients_path(@project), params: { person_id: people(:recipient).id }

    get team_project_path(@project)

    assert_response :success
    assert_select "section[aria-labelledby='members-heading'] li", text: /Rowan Recipient/, count: 0
  end

  test "a Volunteer sees Recipients but cannot manage them" do
    sign_in_as_leader
    post project_recipients_path(@project), params: { person_id: people(:recipient).id }

    sign_in_as_volunteer
    get project_path(@project)

    assert_response :success
    assert_select "section[aria-labelledby='tool-recipients'] li", text: /Rowan Recipient/
    assert_select "section[aria-labelledby='tool-recipients'] a", text: "Add recipient", count: 0

    get new_project_recipient_path(@project)
    assert_response :not_found

    assert_no_difference "Recipient.count" do
      post project_recipients_path(@project), params: { person_id: people(:other_volunteer).id }
    end
    assert_response :not_found
  end

  test "a Leader cannot add a Recipient from another Organization" do
    sign_in_as_leader

    assert_no_difference "Recipient.count" do
      post project_recipients_path(@project), params: { person_id: people(:outsider).id }
    end

    assert_response :not_found
  end

  test "a Person from another Organization cannot read or change Recipients" do
    sign_in_as_leader
    post project_recipients_path(@project), params: { person_id: people(:recipient).id }
    recipient = @project.recipients.find_by!(person: people(:recipient))

    sign_in_as_outsider
    get new_project_recipient_path(@project)
    assert_response :not_found

    assert_no_difference "Recipient.count" do
      post project_recipients_path(@project), params: { person_id: people(:outsider).id }
    end
    assert_response :not_found

    assert_no_difference "Recipient.count" do
      delete project_recipient_path(@project, recipient)
    end
    assert_response :not_found
    assert Recipient.exists?(recipient.id)
  end

  test "a non-member cannot see or manage Recipients" do
    sign_in_as_leader
    post project_recipients_path(@project), params: { person_id: people(:recipient).id }

    sign_in_as(:other_volunteer)
    get project_path(@project)
    assert_response :not_found
  end
end
