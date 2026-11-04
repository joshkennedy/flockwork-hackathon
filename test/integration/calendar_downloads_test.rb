require "test_helper"

class CalendarDownloadsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @slot = @project.slots.create!(date: "2027-02-12", label: "Serve dinner")
    @item = schedule_items(:community_meal_lunch)
  end

  test "a volunteer downloads their claimed Slot and a visible Schedule item" do
    person = sign_in_as_volunteer
    @slot.slot_claims.create!(person: person)

    get project_slot_calendar_path(@project, @slot)
    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_match(/attachment;.*\.ics/, response.headers["Content-Disposition"])
    assert_includes response.body, "SUMMARY:Serve dinner\r\n"

    get project_schedule_item_calendar_path(@project, @item)
    assert_response :success
    assert_includes response.body, "SUMMARY:Lunch\r\n"
  end

  test "a person cannot download an unclaimed or released Slot" do
    person = sign_in_as_volunteer
    get project_slot_calendar_path(@project, @slot)
    assert_response :not_found

    claim = @slot.slot_claims.create!(person: person)
    claim.destroy!
    get project_slot_calendar_path(@project, @slot)
    assert_response :not_found
  end

  test "another church cannot download events" do
    sign_in_as_outsider

    get project_schedule_item_calendar_path(@project, @item)
    assert_response :not_found
    get project_slot_calendar_path(@project, @slot)
    assert_response :not_found
  end

  test "a person outside a private Project cannot download its Schedule" do
    person = organizations(:st_example).people.create!(name: "Outside the Team", email: "outside-team@example.test")
    sign_in_as(person)

    get project_schedule_item_calendar_path(@project, @item)
    assert_response :not_found
  end

  test "a record cannot be downloaded through another Project" do
    sign_in_as_admin
    other = projects(:building_cleanup)

    get project_schedule_item_calendar_path(other, @item)
    assert_response :not_found
    get project_slot_calendar_path(other, @slot)
    assert_response :not_found
  end

  test "deleted Projects do not expose events" do
    sign_in_as_admin
    @project.update!(deleted_at: Time.current)

    get project_schedule_item_calendar_path(@project, @item)
    assert_response :not_found
  end

  test "downloads require a signed-in person" do
    get project_schedule_item_calendar_path(@project, @item)
    assert_redirected_to root_path
  end
end
