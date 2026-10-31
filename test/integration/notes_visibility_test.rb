require "test_helper"

class NotesVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @project.update!(enabled_tools: @project.enabled_tools + [ "recipients" ])
    @recipient = @project.recipients.create!(person: people(:recipient))
    @restricted_author = @project.workspace.people.create!(
      name: "Riley Note Author",
      email: "riley@st-example.test"
    )
    @project.memberships.create!(person: @restricted_author, role: :volunteer)

    Note.create!(
      workspace: @project.workspace,
      notable: @project,
      author: people(:leader),
      visibility: :team,
      body: "Project team note: arrive by five."
    )
    Note.create!(
      workspace: @project.workspace,
      notable: @recipient,
      author: people(:leader),
      visibility: :team,
      body: "Recipient team note: avoid peanuts."
    )
    Note.create!(
      workspace: @project.workspace,
      notable: @project,
      author: @restricted_author,
      visibility: :leaders,
      body: "Project leaders note: follow up privately."
    )
    Note.create!(
      workspace: @project.workspace,
      notable: @project,
      author: @restricted_author,
      visibility: :admins,
      body: "Project admins note: confidential concern."
    )
    Note.create!(
      workspace: @project.workspace,
      notable: @recipient,
      author: people(:leader),
      visibility: :leaders,
      body: "Recipient leaders note: call before visiting."
    )
    Note.create!(
      workspace: @project.workspace,
      notable: @recipient,
      author: people(:admin),
      visibility: :admins,
      body: "Recipient admins note: private care context."
    )
    Note.create!(
      workspace: @project.workspace,
      notable: people(:recipient),
      author: people(:admin),
      visibility: :admins,
      body: "Person admins note: directory context."
    )
  end

  test "a Volunteer sees only Team-visible Project and Recipient Notes" do
    sign_in_as_volunteer
    get project_path(@project)

    assert_response :success
    assert_includes response.body, "Project team note: arrive by five."
    assert_includes response.body, "Recipient team note: avoid peanuts."
    assert_not_includes response.body, "Project leaders note: follow up privately."
    assert_not_includes response.body, "Project admins note: confidential concern."
    assert_not_includes response.body, "Recipient leaders note: call before visiting."
    assert_not_includes response.body, "Recipient admins note: private care context."
    assert_not_includes response.body, "Person admins note: directory context."
    assert_not_includes response.body, "hidden note"
  end

  test "a Leader sees Team and Leaders Notes but no Admins Notes" do
    sign_in_as_leader
    get project_path(@project)

    assert_response :success
    assert_includes response.body, "Project team note: arrive by five."
    assert_includes response.body, "Recipient team note: avoid peanuts."
    assert_includes response.body, "Project leaders note: follow up privately."
    assert_includes response.body, "Recipient leaders note: call before visiting."
    assert_not_includes response.body, "Project admins note: confidential concern."
    assert_not_includes response.body, "Recipient admins note: private care context."
    assert_not_includes response.body, "Person admins note: directory context."
  end

  test "an Admin sees every Project and Recipient Note and Person Notes on the Person edit page" do
    sign_in_as_admin

    get project_path(@project)

    assert_response :success
    assert_includes response.body, "Project team note: arrive by five."
    assert_includes response.body, "Recipient team note: avoid peanuts."
    assert_includes response.body, "Project leaders note: follow up privately."
    assert_includes response.body, "Recipient leaders note: call before visiting."
    assert_includes response.body, "Project admins note: confidential concern."
    assert_includes response.body, "Recipient admins note: private care context."
    assert_not_includes response.body, "Person admins note: directory context."

    get edit_person_path(people(:recipient))

    assert_response :success
    assert_includes response.body, "Person admins note: directory context."
    assert_not_includes response.body, "Project admins note: confidential concern."
    assert_not_includes response.body, "Recipient admins note: private care context."
  end

  test "a Volunteer author sees their own Leaders and Admins Notes" do
    sign_in_as(@restricted_author)
    get project_path(@project)

    assert_response :success
    assert_includes response.body, "Project team note: arrive by five."
    assert_includes response.body, "Recipient team note: avoid peanuts."
    assert_includes response.body, "Project leaders note: follow up privately."
    assert_includes response.body, "Project admins note: confidential concern."
    assert_not_includes response.body, "Recipient leaders note: call before visiting."
    assert_not_includes response.body, "Recipient admins note: private care context."
    assert_not_includes response.body, "Person admins note: directory context."
  end

  test "an Open Team non-member sees no Notes or Recipients" do
    @project.update!(open_team: true)
    sign_in_as(:other_volunteer)

    get project_path(@project)

    assert_response :success
    assert_select "section[aria-labelledby='project-notes-heading']", count: 0
    assert_select "section[aria-labelledby='tool-recipients']", count: 0
    assert_not_includes response.body, "Project team note: arrive by five."
    assert_not_includes response.body, "Recipient team note: avoid peanuts."
    assert_not_includes response.body, "Project leaders note: follow up privately."
    assert_not_includes response.body, "Recipient leaders note: call before visiting."
    assert_not_includes response.body, "Project admins note: confidential concern."
    assert_not_includes response.body, "Recipient admins note: private care context."
    assert_not_includes response.body, "Person admins note: directory context."
  end

  test "an outsider receives not found" do
    sign_in_as_outsider

    get project_path(@project)

    assert_response :not_found
  end

  test "a Volunteer can write Team and Leaders Notes from limited forms" do
    sign_in_as_volunteer
    get project_path(@project)

    assert_response :success
    visibility_selects = css_select("form[data-note-form] select[name='note[visibility]']")
    assert_equal 2, visibility_selects.size
    visibility_selects.each do |select|
      assert_equal [ "team", "leaders" ], select.css("option").map { |option| option["value"] }
    end

    assert_difference "Note.count", 1 do
      post project_notes_path(@project), params: {
        note: {
          notable_type: "Project",
          notable_id: @project.id,
          visibility: "team",
          body: "Volunteer project note: setup starts at four."
        }
      }
    end

    assert_redirected_to project_path(@project)
    follow_redirect!
    assert_includes response.body, "Volunteer project note: setup starts at four."

    assert_difference "Note.count", 1 do
      post project_notes_path(@project), params: {
        note: {
          notable_type: "Recipient",
          notable_id: @recipient.id,
          visibility: "leaders",
          body: "Volunteer recipient note: please follow up privately."
        }
      }
    end

    assert_redirected_to project_path(@project)
    follow_redirect!
    assert_includes response.body, "Volunteer recipient note: please follow up privately."
  end

  test "a Leader can write an Admins Note from a form offering every visibility" do
    sign_in_as_leader
    get project_path(@project)

    assert_response :success
    visibility_selects = css_select("form[data-note-form] select[name='note[visibility]']")
    assert_equal 2, visibility_selects.size
    visibility_selects.each do |select|
      assert_equal [ "team", "leaders", "admins" ], select.css("option").map { |option| option["value"] }
    end

    assert_difference "Note.count", 1 do
      post project_notes_path(@project), params: {
        note: {
          notable_type: "Recipient",
          notable_id: @recipient.id,
          visibility: "admins",
          body: "Leader admins note: restricted follow-up."
        }
      }
    end

    assert_redirected_to project_path(@project)
    assert_equal "admins", Note.order(:id).last.visibility
  end

  test "an Admin writes a Person Note that is forced to Admins visibility" do
    sign_in_as_admin
    person = people(:recipient)
    get edit_person_path(person)

    assert_response :success
    assert_select "form[data-note-form] select[name='note[visibility]'] option" do |options|
      assert_equal [ "admins" ], options.map { |option| option["value"] }
    end

    assert_difference "Note.count", 1 do
      post person_notes_path(person), params: {
        note: {
          notable_type: "Person",
          notable_id: person.id,
          visibility: "team",
          body: "New person note: Admin review only."
        }
      }
    end

    note = Note.order(:id).last
    assert_redirected_to edit_person_path(person)
    assert_equal person, note.notable
    assert_equal people(:admin), note.author
    assert_equal "admins", note.visibility
    assert_equal "New person note: Admin review only.", note.body
  end

  test "an Admin can write an Admins Note on a Project" do
    sign_in_as_admin
    get project_path(@project)

    visibility_selects = css_select("form[data-note-form] select[name='note[visibility]']")
    assert_equal 2, visibility_selects.size
    visibility_selects.each do |select|
      assert_equal [ "team", "leaders", "admins" ], select.css("option").map { |option| option["value"] }
    end

    assert_difference "Note.count", 1 do
      post project_notes_path(@project), params: {
        note: {
          notable_type: "Project",
          notable_id: @project.id,
          visibility: "admins",
          body: "Admin project note: Admin review only."
        }
      }
    end

    assert_redirected_to project_path(@project)
    assert_equal "admins", Note.order(:id).last.visibility
  end

  test "a Volunteer cannot write an Admins Note" do
    sign_in_as_volunteer

    assert_no_difference "Note.count" do
      post project_notes_path(@project), params: {
        note: {
          notable_type: "Project",
          notable_id: @project.id,
          visibility: "admins",
          body: "Rejected volunteer admins note."
        }
      }
    end

    assert_response :not_found
    assert_not Note.exists?(body: "Rejected volunteer admins note.")
  end

  test "a non-Admin cannot write a Person Note" do
    sign_in_as_volunteer
    person = people(:recipient)

    assert_no_difference "Note.count" do
      post person_notes_path(person), params: {
        note: {
          notable_type: "Person",
          notable_id: person.id,
          visibility: "admins",
          body: "Rejected volunteer person note."
        }
      }
    end

    assert_response :not_found
    assert_not Note.exists?(body: "Rejected volunteer person note.")
  end
end
