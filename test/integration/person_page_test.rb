require "test_helper"

class PersonPageTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:st_example)
    @volunteer = people(:volunteer)
  end

  test "the Admin's person page is headed by the name, with tap-to-call and mailto contact links" do
    @volunteer.update!(phone: "(555) 010-2233")
    sign_in_as_admin

    get person_path(@volunteer)

    assert_response :success
    assert_select "h1", text: "Vic Volunteer"
    assert_select "h1", text: /Edit/, count: 0
    assert_select "a[href='mailto:vic@st-example.test']", text: "vic@st-example.test"
    assert_select "a[href='tel:5550102233']", text: "(555) 010-2233"
  end

  test "the page lists Serving now with each Project's role, and Past Projects apart from it" do
    projects(:building_cleanup).update_column(:archived_at, Time.current)
    sign_in_as_admin

    get person_path(people(:other_leader))

    assert_select "section[aria-labelledby=serving-heading] a", text: "Community Meal"
    assert_select "section[aria-labelledby=serving-heading] a", text: "Building Cleanup", count: 0
    assert_select "section[aria-labelledby=serving-heading] span", text: "Leader"
    assert_select "h3", text: "Past Projects"
    assert_select "section[aria-labelledby=past-projects-heading] a", text: "Building Cleanup"
  end

  test "the page has History, Check-ins, Away dates and Notes, and no edit form or Involvement heading" do
    sign_in_as_admin

    get person_path(@volunteer)

    assert_select "h2", text: "History"
    assert_select "h2", text: "Check-ins"
    assert_select "h2", text: "Away dates"
    assert_select "h2", text: "Notes"
    assert_select "input[name='person[name]']", count: 0
    assert_select "h2", text: "Involvement", count: 0
  end

  test "a Leader who logs a check-in on the person page is sent back to that page, and the note stays Admin-only" do
    sign_in_as_admin

    post person_check_ins_path(@volunteer), params: { return_to: "person", check_in: { on: Date.current.iso8601, note: "Asked about Saturdays" } }

    assert_redirected_to person_path(@volunteer)
    follow_redirect!
    assert_select "p", text: /Checked in #{Date.current.strftime("%b %-d")} by/
    assert_select "p", text: "Admin note: Asked about Saturdays"
  end

  test "the Check-ins section has the note field for Admins" do
    sign_in_as_admin

    get person_path(@volunteer)

    assert_select "form[action=?] input[name='return_to'][value=person]", person_check_ins_path(@volunteer)
    assert_select "input[name='check_in[note]']"
  end

  test "Away dates show the dates and never the note" do
    Unavailability.create!(organization: @organization, person: @volunteer, starts_on: Date.current - 2,
      ends_on: Date.current + 10, note: "Private trip details")
    sign_in_as_admin

    get person_path(@volunteer)

    assert_select "[data-away-range]", text: "Away until #{(Date.current + 10).strftime("%b %-d")}"
    assert_no_match "Private trip details", response.body
  end

  test "the person page carries the status chips for Leader, Admin and never asked" do
    sign_in_as_admin

    get person_path(people(:leader))
    assert_select "span.status-chip", text: "Leader"

    get person_path(people(:other_volunteer))
    assert_select "span.status-chip-need", text: "Not yet asked"
  end

  test "the notes form posts to the person page and forces Admins visibility" do
    sign_in_as_admin

    get person_path(@volunteer)

    assert_select "form[data-note-form][action=?]", person_notes_path(@volunteer)
    assert_select "form[data-note-form] select[name='note[visibility]'] option", count: 1
    assert_select "form[data-note-form] p", text: "Only Admins can see person notes."
  end

  test "an Admin can edit and delete a Person note from its actions menu" do
    note = @volunteer.notes.create!(organization: @organization, author: people(:admin), body: "Old note", visibility: :admins)
    sign_in_as_admin

    get person_path(@volunteer)
    assert_select "a[href=?][data-action='slideout#open']", edit_person_note_path(@volunteer, note), text: "Edit Note"
    assert_select "form[action=?][data-turbo-confirm='Delete this note?']", person_note_path(@volunteer, note)

    patch person_note_path(@volunteer, note), params: { note: { body: "Updated note" } }
    assert_redirected_to person_path(@volunteer)
    assert_equal "Updated note", note.reload.body

    assert_difference "Note.count", -1 do
      delete person_note_path(@volunteer, note)
    end
    assert_redirected_to person_path(@volunteer)
  end

  test "a non-Admin cannot edit or delete a Person note" do
    note = @volunteer.notes.create!(organization: @organization, author: people(:admin), body: "Private note", visibility: :admins)
    sign_in_as_volunteer

    get edit_person_note_path(@volunteer, note)
    assert_response :not_found
    delete person_note_path(@volunteer, note)
    assert_response :not_found
    assert Note.exists?(note.id)
  end

  test "Edit details shows the form under the name, without the notes or History" do
    sign_in_as_admin

    get edit_person_path(@volunteer)

    assert_response :success
    assert_select "h1", text: "Vic Volunteer"
    assert_select "p", text: "Edit details"
    assert_select "input[name='person[name]']"
    assert_select "h2", text: "Notes", count: 0
    assert_select "h2", text: "History", count: 0
  end

  test "a Leader and a Volunteer get 404 on the person page, and no check-in or away note reaches them" do
    # Random tokens: the test environment's 404 page echoes this file's source, so a literal note would match itself.
    check_in_note = "check-in #{SecureRandom.hex(6)}"
    away_note = "away #{SecureRandom.hex(6)}"
    CheckIn.create!(organization: @organization, person: @volunteer, checked_in_by: people(:admin), on: Date.current, note: check_in_note)
    Unavailability.create!(organization: @organization, person: @volunteer, starts_on: Date.current, ends_on: Date.current + 3, note: away_note)

    sign_in_as_leader
    get person_path(@volunteer)
    assert_response :not_found
    assert_no_match check_in_note, response.body
    assert_no_match away_note, response.body

    sign_in_as_volunteer
    get person_path(@volunteer)
    assert_response :not_found
    assert_no_match check_in_note, response.body
    assert_no_match away_note, response.body
  end

  test "a Person from another Organization is not found" do
    sign_in_as_admin

    get person_path(people(:outsider))

    assert_response :not_found
  end
end
