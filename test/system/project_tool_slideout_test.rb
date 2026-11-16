require "application_system_test_case"

class ProjectToolSlideoutSystemTest < ApplicationSystemTestCase
  setup do
    @project = Project.create_for(
      creator: people(:grace_leader),
      attributes: {
        name: "Slideout Project",
        description: "Forms stay with their Project.",
        starts_on: Date.new(2027, 3, 12),
        ends_on: Date.new(2027, 3, 13),
        enabled_tools: %w[tasks schedule budget]
      }
    )
    sign_in_as_leader_in_browser
  end

  test "Task validation and save stay in the slideout with keyboard focus restored" do
    visit project_path(@project)
    trigger = find_link("Add Task")
    trigger.click

    within "dialog.slideout[open]" do
      assert_selector "h2", text: "Add Task"
      assert_selector "input[name='task[title]']:focus"
    end

    page.send_keys(:escape)
    assert_no_selector "dialog.slideout[open]"
    assert_equal trigger, page.active_element

    trigger.click
    within "dialog.slideout[open]" do
      find_field("Title").execute_script("this.removeAttribute('required')")
      click_on "Add Task"
      assert_selector "[role=alert]", text: "Title can't be blank"
      fill_in "Title", with: "Set the tables"
      click_on "Add Task"
    end

    assert_no_selector "dialog.slideout[open]"
    assert_current_path project_path(@project)
    assert_text "Set the tables"
  end

  test "Schedule item validation and save stay in the slideout" do
    visit project_path(@project)
    click_link "Schedule", exact: true
    click_on "Add Item"

    within "dialog.slideout[open]" do
      assert_selector "h2", text: "Add Schedule Item"
      assert_selector "input[name='schedule_item[date]']:focus"
      fill_in "Date", with: "2027-03-12"
      fill_in "Start time", with: "10:00"
      fill_in "End time", with: "09:00"
      fill_in "Title", with: "Volunteer briefing"
      click_on "Add Schedule Item"
      assert_selector "[role=alert]", text: "End time must be at or after the start time"
      fill_in "End time", with: "10:30"
      click_on "Add Schedule Item"
    end

    assert_no_selector "dialog.slideout[open]"
    assert_current_path project_path(@project)
    assert_text "Volunteer briefing"
  end

  test "Budget line validation and save stay in the slideout" do
    visit project_path(@project)
    click_link "Budget", exact: true
    click_on "Add Purchase"

    within "dialog.slideout[open]" do
      assert_selector "h2", text: "Add Purchase"
      assert_selector "input[name='budget_line[description]']:focus"
      fill_in "Description", with: "Serving trays"
      fill_in "Estimated cost", with: "not money"
      click_on "Add Purchase"
      assert_selector "[role=alert]", text: "Estimated cost must be a dollar amount"
      fill_in "Estimated cost", with: "85.00"
      click_on "Add Purchase"
    end

    assert_no_selector "dialog.slideout[open]"
    assert_current_path project_path(@project)
    assert_text "Serving trays"
    assert_text "$85.00"
  end

  test "the Budget tab stays in the URL through a reload" do
    visit project_path(@project)

    click_link "Budget", exact: true

    assert_equal "tab-budget", URI.parse(page.current_url).fragment
    page.refresh
    assert_selector "#tab-budget:not([hidden])"
  end

  test "Task primary action stays reachable when its long form opens on a phone" do
    page.current_window.resize_to(390, 844)
    visit project_path(@project)
    click_on "Add Task"

    within "dialog.slideout[open]" do
      action_bounds = find_button("Add Task").evaluate_script("this.getBoundingClientRect().toJSON()")
      viewport_height = page.evaluate_script("window.innerHeight")

      assert_operator action_bounds.fetch("top"), :>=, 0
      assert_operator action_bounds.fetch("bottom"), :<=, viewport_height
      assert_equal 0, find(".slideout-panel").evaluate_script("this.scrollTop")
    end
  end

  private
    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end
end
