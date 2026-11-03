require "application_system_test_case"

class GeneralPlannerSystemTest < ApplicationSystemTestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "a Leader reviews grouped Tool previews and arrives at the first accepted Tool" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      response(card: card("What should this workday accomplish?", "Repair the playground", "Prepare the garden", "Clean the building")),
      response(finished: true, added: project_items)
    ])
    sign_in_as_leader_in_browser
    page.current_window.resize_to(1200, 760)

    visit new_project_path
    click_button "Workday"
    assert_text "What should this workday accomplish?"
    assert_text "Your Project will take shape here"

    click_button "Repair the playground"
    assert_text "Preview updated. Change your choice or continue."
    within ".meal-preview-heading" do
      assert_text "6 items"
    end

    within "section[aria-labelledby='pending-tool-tasks']" do
      assert_text "Tasks"
      assert_text "Confirm volunteer crew"
    end
    within "section[aria-labelledby='pending-tool-schedule']" do
      assert_text "Schedule"
      assert_text "Morning briefing"
    end
    within "section[aria-labelledby='pending-tool-signup_sheet']" do
      assert_text "Sign-up sheet"
      assert_text "Work crew", count: 2
    end
    within "section[aria-labelledby='pending-tool-budget']" do
      assert_text "Budget"
      assert_text "Paint and brushes"
    end
    within "section[aria-labelledby='pending-tool-list']" do
      assert_text "List"
      assert_text "Supply checklist"
    end

    click_button "Finish with This"
    assert_text "Here’s what will be added"
    click_button "Add to Project"

    planner_session = PlannerSession.order(:id).last!
    assert_equal "tasks", planner_session.acceptance_tool
    assert_current_path project_path(planner_session.project, added_plan: planner_session.id)
    within "section[aria-labelledby='tool-tasks']" do
      assert_text "Confirm volunteer crew"
    end
    assert_selector "#tool-tasks", focused: true
    assert_selector "a.tab-link[aria-current='true']", text: Project::TOOL_LABELS.fetch("tasks")
    section_top = page.evaluate_script("document.querySelector('[aria-labelledby=tool-tasks]').getBoundingClientRect().top")
    assert_operator section_top, :>=, 0
    assert_operator section_top, :<, page.evaluate_script("window.innerHeight")
  end

  test "a relative task date can be resolved directly at the finish" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      response(card: card("What matters first?", "Preparation", "Supplies", "Schedule")),
      response(finished: true, added: [ item("task", "prepare", title: "Prepare the room", details: "", due_in_days: -1) ])
    ])
    sign_in_as_leader_in_browser
    visit new_project_path
    click_button "Workday"
    click_button "Preparation"
    assert_text "Preview updated. Change your choice or continue."
    assert_no_text "Choose a Project start date or a due date"
    click_button "Finish with This"
    fill_in "Project start date", with: "2027-04-10"
    click_button "Set Date"
    assert_text "Due April 9, 2027"
    click_button "Add to Project"
    assert_selector "#tool-tasks", focused: true
    assert_equal Date.new(2027, 4, 9), PlannerSession.order(:id).last!.project.tasks.sole.due_on
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
      { "question" => question, "options" => options }
    end

    def project_items
      [
        item("task", "confirm-crew", title: "Confirm volunteer crew", details: "Call the team.", due_on: "2027-04-09"),
        item("schedule_item", "briefing", title: "Morning briefing", date: "2027-04-10", starts_at: "08:30", ends_at: "09:00", location: "Main entrance"),
        item("slot_run", "work-crew", label: "Work crew", start_date: "2027-04-10", end_date: "2027-04-11", time: "09:00", capacity: 4),
        item("purchase", "paint", description: "Paint and brushes", estimated_dollars: 125.50),
        item("list", "supplies", name: "Supply checklist", columns: [ { name: "Item", type: "text" }, { name: "Packed", type: "checkbox" } ])
      ]
    end

    def item(kind, source_key, **fields)
      { "kind" => kind, "source_key" => source_key, "fields" => fields.stringify_keys }
    end
end
