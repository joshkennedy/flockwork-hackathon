require "test_helper"

class ScheduleItemsTest < ActionDispatch::IntegrationTest
  test "a Leader creates, edits, and deletes Schedule items" do
    sign_in_as_leader
    project = projects(:community_meal)

    assert_difference "ScheduleItem.count", 1 do
      post project_schedule_items_path(project), params: {
        schedule_item: {
          date: "2027-02-14",
          title: "Closing Worship",
          location: "Sanctuary"
        }
      }
    end

    item = project.schedule_items.find_by!(title: "Closing Worship")
    assert_redirected_to project_path(project)
    follow_redirect!
    assert_match "Closing Worship", response.body
    assert_match "Sanctuary", response.body

    patch project_schedule_item_path(project, item), params: {
      schedule_item: {
        date: "2027-02-14",
        starts_at_time: "18:00",
        ends_at_time: "19:00",
        title: "Closing Worship & Send-off",
        location: "Sanctuary"
      }
    }

    assert_redirected_to project_path(project)
    assert_equal "Closing Worship & Send-off", item.reload.title
    assert_equal "18:00", item.starts_at_time.strftime("%H:%M")
    assert_equal "19:00", item.ends_at_time.strftime("%H:%M")

    assert_difference "ScheduleItem.count", -1 do
      delete project_schedule_item_path(project, item)
    end

    assert_redirected_to project_path(project)
    follow_redirect!
    assert_no_match "Closing Worship & Send-off", response.body
  end

  test "Schedule items render grouped by day with untimed items first and timed items in order" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    get project_path(project)

    assert_response :success
    assert_select "section[aria-labelledby='tool-schedule'] h3", text: "Friday, February 12"
    assert_select "section[aria-labelledby='tool-schedule'] h3", text: "Saturday, February 13"

    assert_select "section[aria-labelledby='tool-schedule']" do
      titles = css_select("section[aria-labelledby='tool-schedule'] span.font-semibold").map(&:text)
      assert_equal [
        "Arrival",
        "Opening Session",
        "Lunch",
        "Day Two Kickoff"
      ], titles
    end
  end

  test "a Volunteer views Schedule items but gets 404 on new and edit" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    item = schedule_items(:community_meal_opening)

    get project_path(project)

    assert_response :success
    assert_select "span.font-semibold", text: "Opening Session"
    assert_select "a", text: "Add item", count: 0
    assert_select "a", text: "Edit", count: 0

    get new_project_schedule_item_path(project)

    assert_response :not_found

    get edit_project_schedule_item_path(project, item)

    assert_response :not_found
  end

  test "a non-member gets 404 on Schedule item routes" do
    sign_in_as_outsider
    project = projects(:community_meal)
    item = schedule_items(:community_meal_opening)

    get project_path(project)

    assert_response :not_found

    get new_project_schedule_item_path(project)

    assert_response :not_found

    post project_schedule_items_path(project), params: {
      schedule_item: { date: "2027-02-12", title: "Sneak In" }
    }

    assert_response :not_found

    get edit_project_schedule_item_path(project, item)

    assert_response :not_found
  end

  test "a Leader can manage Schedule items when the Schedule Tool is disabled" do
    sign_in_as(:other_leader)
    project = projects(:building_cleanup)

    assert_empty project.enabled_tools

    get new_project_schedule_item_path(project)

    assert_response :success

    assert_difference "ScheduleItem.count", 1 do
      post project_schedule_items_path(project), params: {
        schedule_item: { date: "2027-03-20", title: "Setup" }
      }
    end

    assert_redirected_to project_path(project)
  end
end
