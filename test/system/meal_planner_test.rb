require "application_system_test_case"

class MealPlannerSystemTest < ApplicationSystemTestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "a Leader previews edits resumes and adds a meal train" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      response(card: card("Which meals should people bring?", "Dinner", "Lunch")),
      response(finished: true, added: [ slot_run ])
    ])
    sign_in_as_leader_in_browser
    page.current_window.resize_to(1200, 700)

    visit new_project_path
    click_button "Meal Train"
    assert_text "Which meals should people bring?"
    assert_text "The first meal will appear here"

    click_button "Dinner"
    assert_text "Preview updated. Change your choice or continue."
    assert_text "3 meal slots"
    assert_selector "button[aria-pressed='true']", text: "Dinner"
    assert_selector "article.meal-slot-changed", count: 3
    assert_selector "#planner-announcer", text: "Preview updated. Change your choice or continue.", visible: :all

    first_meal = all("article.meal-slot").first
    within first_meal do
      find("summary", text: "Edit").click
      fill_in "Meal", with: "Bring soup"
      fill_in "Time", with: "18:30"
      fill_in "People needed", with: "2"
      click_button "Save Changes"
    end
    assert_text "Bring soup"
    assert_text "6:30 PM"
    assert_selector "article.meal-slot-changed", count: 1, text: "Bring soup"

    within all("article.meal-slot")[1] do
      find("summary", text: "Edit").click
      click_button "Remove Meal"
    end
    assert_text "2 meal slots"
    assert_text "Meal removed."
    click_button "Undo"
    assert_text "3 meal slots"

    planner_path = page.current_path
    click_button "Save and Leave"
    assert_no_current_path planner_path
    assert_text "Organize meals for a meal train."
    click_on "Continue Planning"
    assert_current_path planner_path
    assert_text "Bring soup"
    assert_text "3 meal slots"

    click_button "Continue"
    assert_text "Here’s your meal train"
    click_button "Add to Project"

    within "section[aria-labelledby='tool-signup-sheet']" do
      assert_text "3 meals added to your Sign-up sheet."
      assert_text "Bring soup"
      assert_text "Bring dinner", count: 2
      assert_text "2 spots left"
    end
    assert_selector "#tool-signup-sheet", focused: true
    assert_selector "a.tab-link[aria-current='true']", text: Project::TOOL_LABELS.fetch("signup_sheet")
    section_top = page.evaluate_script("document.querySelector('[aria-labelledby=tool-signup-sheet]').getBoundingClientRect().top")
    assert_operator section_top, :>=, 0
    assert_operator section_top, :<, page.evaluate_script("window.innerHeight")
  end

  test "a busy frame recovers after generation finishes without a broadcast" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      response(card: card("Which meals should people bring?", "Dinner", "Lunch"))
    ])
    sign_in_as_leader_in_browser
    ActiveJob::Base.queue_adapter = :test

    visit new_project_path
    click_button "Meal Train"
    assert_text "Preparing your first choice…"
    planner_session = PlannerSession.order(:id).last!
    revision = planner_session.generation_revision
    assert_equal "queued", planner_session.generation_state

    sleep 3.25
    assert_text "Preparing your first choice…"
    browser_session = people(:grace_leader).sessions.order(:id).last!
    assert Current.set(session: browser_session) { planner_session.generate!(revision:) }

    assert_text "Which meals should people bring?", wait: 8
    assert_button "Dinner"
    assert_equal "idle", planner_session.reload.generation_state
  end

  private
    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end

    def response(card: nil, finished: false, added: [])
      Planner::Response.new(card:, finished:, added:, removed_ids: [])
    end

    def card(question, *options)
      options << "Something else" while options.size < 3
      { "question" => question, "options" => options }
    end

    def slot_run
      {
        "kind" => "slot_run",
        "source_key" => "meal-slots",
        "fields" => {
          "label" => "Bring dinner",
          "start_date" => "2027-02-15",
          "end_date" => "2027-02-17",
          "time" => "17:30",
          "capacity" => 1
        }
      }
    end
end
