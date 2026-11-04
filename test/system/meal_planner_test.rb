require "application_system_test_case"

class MealPlannerSystemTest < ApplicationSystemTestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @provider = Planner::Providers::Fake.new([])
    Rails.configuration.x.planner_provider = @provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
  end

  test "a Leader configures edits resumes and adds meals from one form" do
    sign_in_as_leader_in_browser
    page.current_window.resize_to(1200, 850)
    visit new_project_path
    click_button "Meal Train"
    assert_field "Meal", with: "Dinner"
    assert_no_text "Question 1 of 3"
    assert_no_text "The planner sees"

    fill_in "First meal date", with: "2027-02-15"
    fill_in "Days", with: "3"
    fill_in "Delivery time", with: "17:30"
    assert_text "3 meal slots"
    assert_selector "input[type='submit'][value='Add 3 Meal Slots']:not([disabled])"

    within all("article.meal-slot").first do
      find("summary[aria-label='Edit meal 1']").click
      fill_in "Meal", with: "Bring soup"
      fill_in "Time", with: "18:30"
      fill_in "People needed", with: "2"
      click_button "Save", exact: true
    end
    assert_text "Bring soup"
    assert_text "6:30 PM"
    fill_in "Project name", with: "Meals with soup"
    assert_text "Details saved"
    assert_no_text "another tab"

    within all("article.meal-slot")[1] do
      find("summary").click
      click_button "Remove", exact: true
    end
    assert_text "2 meal slots"
    click_button "Undo"
    assert_text "3 meal slots"

    planner_path = page.current_path
    click_link "Back to Project"
    assert_no_current_path planner_path
    click_link "Finish Meal Setup"
    assert_current_path planner_path
    assert_text "Bring soup"
    assert_field "First meal date", with: "2027-02-15"
    click_button "Add 3 Meal Slots"

    within "section[aria-labelledby='tool-signup-sheet']" do
      assert_text "3 meals added to your Sign-up sheet."
      assert_text "Bring soup"
      assert_text "2 spots left"
    end
    assert_selector "#tool-signup-sheet", focused: true
    assert_empty @provider.contexts
  end

  test "leaving immediately after typing flushes the latest draft on a phone" do
    sign_in_as_leader_in_browser
    page.current_window.resize_to(390, 844)
    visit new_project_path
    click_button "Meal Train"
    fill_in "Project name", with: "November meals"
    fill_in "Meal", with: "Soup and bread"
    fill_in "First meal date", with: "2027-02-15"
    fill_in "Days", with: "7"
    select "Every 2 days", from: "Frequency"
    click_link "Back to Project"
    assert_selector "h1", text: "November meals"
    click_link "Finish Meal Setup"
    assert_field "Meal", with: "Soup and bread"
    assert_field "Days", with: "7"
    assert_select "Frequency", selected: "Every 2 days"
    assert_text "4 meal slots"
    assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    assert_empty @provider.contexts
  end

  test "a failed autosave retains typed input and Retry Saving recovers it" do
    sign_in_as_leader_in_browser
    visit new_project_path
    click_button "Meal Train"
    page.execute_script <<~JS
      const originalFetch = window.fetch;
      window.fetch = (...args) => {
        if (String(args[0]).endsWith('/meal_setup')) {
          window.fetch = originalFetch;
          return Promise.reject(new Error('Connection lost'));
        }
        return originalFetch(...args);
      };
    JS
    fill_in "Meal", with: "Soup and bread"
    assert_text "Changes not saved"
    assert_field "Meal", with: "Soup and bread"
    click_button "Retry Saving"
    assert_text "Details saved"
    click_link "Back to Project"
    click_link "Finish Meal Setup"
    assert_field "Meal", with: "Soup and bread"
    assert_empty @provider.contexts
  end

  test "other navigation flushes the draft before leaving" do
    sign_in_as_leader_in_browser
    page.current_window.resize_to(1200, 850)
    visit new_project_path
    click_button "Meal Train"
    assert_field "Meal", with: "Dinner"
    planner_path = page.current_path
    fill_in "Project name", with: "Saved from navigation"
    click_link "Home", exact: true
    assert_selector "h1", text: "Hi Maria"
    visit planner_path
    assert_field "Project name", with: "Saved from navigation"
  end

  test "a row edit waits for a pending bulk save without losing its fields" do
    sign_in_as_leader_in_browser
    page.current_window.resize_to(1200, 850)
    visit new_project_path
    click_button "Meal Train"
    fill_in "First meal date", with: "2027-02-15"
    fill_in "Days", with: "3"
    assert_text "3 meal slots"
    first_meal = all("article.meal-slot").first
    within first_meal do
      find("summary").click
      fill_in "Meal", with: "Soup and bread"
    end
    fill_in "Project name", with: "Edited meals"
    assert_text "Details saved"
    within first_meal do
      assert_field "Meal", with: "Soup and bread"
    end
    fill_in "Project name", with: "Edited meals again"
    within first_meal do
      click_button "Save", exact: true
    end
    assert_text "Soup and bread"
    assert_field "Project name", with: "Edited meals again"
    assert_no_text "Changes not saved"
    first_meal = all("article.meal-slot").first
    within first_meal do
      find("summary").click
    end
    assert_selector "input[type='submit'][disabled][value='Add 3 Meal Slots']"
    assert_text "Save or cancel the meal you’re editing"
    within first_meal do
      click_button "Cancel"
    end
    assert_selector "input[type='submit'][value='Add 3 Meal Slots']:not([disabled])"
  end

  test "a stale tab can reload the saved setup without retrying its rejected changes" do
    sign_in_as_leader_in_browser
    visit new_project_path
    click_button "Meal Train"
    assert_field "Meal", with: "Dinner"
    session = PlannerSession.order(:id).last!
    session.save_meal_setup!(session.meal_setup.merge("name" => "Saved in another tab"), expected_revision: session.generation_revision)
    fill_in "Meal", with: "Soup"
    assert_text "This setup changed in another tab"
    click_link "Reload Saved Setup"
    assert_field "Project name", with: "Saved in another tab"
    assert_field "Meal", with: "Dinner"
    assert_no_text "Changes not saved"
  end

  test "preview columns align and popovers do not expand rows or escape a phone" do
    sign_in_as_leader_in_browser
    page.current_window.resize_to(1200, 850)
    visit new_project_path
    click_button "Meal Train"
    fill_in "First meal date", with: "2027-02-15"
    fill_in "Days", with: "7"
    assert_text "7 meal slots"
    assert_selector "input[name='meal_setup[name]']", count: 1
    assert_no_selector "h1", exact_text: "Meal train", visible: true

    metrics = page.evaluate_script <<~JS
      [...document.querySelectorAll('.meal-slot-summary')].map(row => ({
        left: row.children[1].getBoundingClientRect().left,
        height: row.getBoundingClientRect().height
      }))
    JS
    assert_equal 1, metrics.map { |row| row.fetch("left") }.uniq.size
    within all("article.meal-slot").first do
      find("summary").click
    end
    assert_selector ".meal-setup-slot-popover", visible: true
    assert_equal "absolute", page.evaluate_script("getComputedStyle(document.querySelector('details[open] .popover-in')).position")
    button_tops = page.evaluate_script("[...document.querySelectorAll('details[open] .meal-slot-actions button')].map(button => button.getBoundingClientRect().top)")
    assert_equal 1, button_tops.uniq.size
    assert_equal metrics.map { |row| row.fetch("height") }, page.evaluate_script("[...document.querySelectorAll('.meal-slot-summary')].map(row => row.getBoundingClientRect().height)")
    page.driver.with_playwright_page { |browser| browser.keyboard.press("Escape") }
    assert_no_selector "details.meal-slot-editor[open]"

    page.current_window.resize_to(320, 740)
    within all("article.meal-slot").last do
      find("summary").click
    end
    assert_selector ".meal-setup-slot-popover", visible: true
    bounds = page.evaluate_script <<~JS
      (() => {
        const box = document.querySelector('details[open] .popover-in').getBoundingClientRect();
        return { left: box.left, right: box.right, top: box.top, bottom: box.bottom, width: innerWidth, height: innerHeight };
      })()
    JS
    assert_operator bounds.fetch("left"), :>=, 0
    assert_operator bounds.fetch("right"), :<=, bounds.fetch("width")
    assert_operator bounds.fetch("top"), :>=, 0
    assert_operator bounds.fetch("bottom"), :<=, bounds.fetch("height") - 64
  end

  test "Add remains reachable when a long preview is scrolled" do
    sign_in_as_leader_in_browser
    page.current_window.resize_to(1200, 850)
    visit new_project_path
    click_button "Meal Train"
    fill_in "First meal date", with: "2027-02-15"
    fill_in "Days", with: "60"
    assert_text "60 meal slots"
    page.execute_script("window.scrollTo(0, 1200)")
    assert_action_in_viewport

    page.current_window.resize_to(390, 844)
    page.execute_script("window.scrollTo(0, 1600)")
    assert_action_in_viewport
  end

  test "clearing the name stays quiet and save status belongs beside the back button" do
    sign_in_as_leader_in_browser
    visit new_project_path
    click_button "Meal Train"
    fill_in "Project name", with: ""
    within ".meal-setup-toolbar" do
      assert_selector "a.btn-secondary", text: "Back to Project"
      assert_text "Details saved"
    end
    assert_no_selector ".meal-setup-error", visible: true
    assert_equal "", PlannerSession.order(:id).last!.meal_setup.fetch("name")
    fill_in "Project name", with: "Meals for friends"
    assert_text "Details saved"
    assert_equal "Meals for friends", PlannerSession.order(:id).last!.project.name
  end

  test "Enter saves the editable name without adding the meal sheet" do
    sign_in_as_leader_in_browser
    visit new_project_path
    click_button "Meal Train"
    fill_in "First meal date", with: "2027-02-15"
    fill_in "Days", with: "2"
    assert_selector "input[type='submit'][value='Add 2 Meal Slots']:not([disabled])"
    planner_path = page.current_path
    fill_in "Project name", with: "Evening meals"
    find_field("Project name").send_keys(:enter)
    assert_text "Details saved"
    assert_current_path planner_path
    session = PlannerSession.order(:id).last!
    assert_equal "Evening meals", session.project.name
    assert_empty session.project.slots
    assert_not_predicate session, :accepted?
  end

  private
    def assert_action_in_viewport
      bounds = page.evaluate_script("(() => { const box = document.querySelector('.meal-setup-add').getBoundingClientRect(); return { top: box.top, bottom: box.bottom, height: innerHeight }; })()")
      assert_operator bounds.fetch("top"), :>=, 0
      assert_operator bounds.fetch("bottom"), :<=, bounds.fetch("height") - (page.evaluate_script("innerWidth") < 768 ? 64 : 0)
    end

    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end
end
