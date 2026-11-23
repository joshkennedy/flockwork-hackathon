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
    page.current_window.resize_to(1440, 1000)

    visit new_project_path
    assert_selector "li[aria-current='step']", text: "What are you organizing?"
    capture_setup("new-1440")
    page.current_window.resize_to(390, 844)
    capture_setup("new-390")
    find("summary", text: "Something Else").click
    fill_in "Describe it and the Planner will take it from there", with: "Organize a cleanup."
    assert_button "Start"
    find("summary", text: "Something Else").click
    page.current_window.resize_to(1440, 1000)
    click_button "Workday"
    assert_text "What should this workday accomplish?"
    assert_text "Your Project will take shape here"
    assert_selector "li[aria-current='step']", text: "Answer a few questions"
    capture_setup("builder-asking-1440")

    click_button "Repair the playground"
    assert_selector "li[aria-current='step']", text: "Review and add"
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

    assert_no_text "Here’s what will be added"
    assert_selector "li[aria-current='step']", text: "Review and add"
    assert_selector "li[data-step-state='done']", text: "1 answer"
    capture_setup("builder-reviewing-1440")
    find("summary[aria-label='Change earlier choices']").click
    within ".setup-step-change" do
      find(".meal-answer-summary > summary").click
      assert_button "Prepare the garden"
    end
    find("summary[aria-label='Change earlier choices']").click
    assert_field "Project name", with: "Workday"
    fill_in "Project name", with: "Playground repair day"
    click_button "Add to Project"

    planner_session = PlannerSession.order(:id).last!
    assert_equal "tasks", planner_session.acceptance_tool
    assert_current_path project_path(planner_session.project, added_plan: planner_session.id)
    assert_selector "h1", text: "Playground repair day"
    within "section[aria-labelledby='tool-tasks']" do
      assert_text "Confirm volunteer crew"
    end
    assert_selector "#tool-tasks", focused: true
    assert_selector "a.tab-link[aria-current='true']", text: Project::TOOL_LABELS.fetch("tasks")
    section_top = page.evaluate_script("document.querySelector('[aria-labelledby=tool-tasks]').getBoundingClientRect().top")
    assert_operator section_top, :>=, 0
    assert_operator section_top, :<, page.evaluate_script("window.innerHeight")
    find("summary[aria-label='Actions for #{planner_session.project.reload.name}']").click
    assert_link "Rename", href: edit_project_path(planner_session.project)
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
    assert_selector "li[aria-current='step']", text: "Review and add"
    assert_no_text "Choose a Project start date or a due date"
    fill_in "Workday date", with: "2027-04-10"
    assert_text "Due April 9, 2027"
    click_button "Add to Project"
    assert_selector "#tool-tasks", focused: true
    assert_equal Date.new(2027, 4, 9), PlannerSession.order(:id).last!.project.tasks.sole.due_on
  end

  test "Project name saves with Enter and blur and restores empty names on a phone" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      response(card: card("What matters first?", "Preparation", "Supplies", "Schedule")),
      response(finished: true, added: [ item("task", "prepare", title: "Prepare the room", details: "", due_on: "2027-04-09") ])
    ])
    sign_in_as_leader_in_browser
    page.current_window.resize_to(390, 844)
    visit new_project_path
    click_button "Workday"
    assert_text "What matters first?"
    field = find(".meal-setup-name")
    field.set("Spring workday")
    field.send_keys(:enter)
    assert_selector "#meal-project-heading", text: "Spring workday", visible: :all
    assert_equal "Spring workday", PlannerSession.order(:id).last!.project.name

    fill_in "Project name", with: ""
    find("#meal-guide-heading").click
    assert_field "Project name", with: "Spring workday"

    click_button "Preparation"
    assert_selector "li[aria-current='step']", text: "Review and add"
    assert_selector "li[aria-current='step']", text: "Review and add"
    assert_no_text "Here’s what will be added"
    fill_in "Project name", with: "Saturday workday"
    find("#meal-preview-heading").click
    assert_selector "#meal-project-heading", text: "Saturday workday", visible: :all
    assert_field "Project name", with: "Saturday workday"
    assert_no_selector "summary", text: "Project Details"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  end

  test "a Class date autosaves and leaves only the review actions" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      response(card: card("What should happen first?", "Prepare the first lesson", "Order materials", "Invite teachers")),
      response(finished: true, added: [ item("task", "prepare", title: "Prepare the first lesson", details: "", due_in_days: -1) ])
    ])
    sign_in_as_leader_in_browser
    visit new_project_path
    click_button "Class"
    click_button "Prepare the first lesson"
    assert_selector "li[aria-current='step']", text: "Review and add"

    assert_field "First class date"
    assert_button "Add to Project", disabled: true
    assert_button "Save and Leave"
    assert_no_text "Here’s what will be added"
    assert_no_text "Items are dated from this day."
    assert_no_button "Save Date"
    capture_class_review("before-date-1440", 1440, 1000)
    capture_class_review("before-date-390", 390, 844)

    fill_in "First class date", with: "2027-04-10"
    assert_field "First class date", with: "2027-04-10"
    assert_text "Due April 9, 2027"
    assert_button "Add to Project", disabled: false
    assert_button "Save and Leave"
    capture_class_review("after-date-1440", 1440, 1000)
    capture_class_review("after-date-390", 390, 844)
  end

  test "a blocker badge opens its row editor and focuses the invalid field" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      response(card: card("What should happen first?", "Set the schedule", "Prepare materials", "Invite teachers")),
      response(finished: true, added: [ item("schedule_item", "opening", title: "Opening class", date: nil, starts_at: "09:00", ends_at: "10:00", location: "Classroom") ])
    ])
    sign_in_as_leader_in_browser
    visit new_project_path
    click_button "Class"
    click_button "Set the schedule"
    assert_selector "li[aria-current='step']", text: "Review and add"

    assert_no_field "First class date"
    assert_text "Fix the highlighted item to add"
    click_button "Needs details"
    assert_field "Date", focused: true
  end

  private
    def capture_setup(name)
      return unless ENV["SETUP_SCREENSHOTS"]

      directory = Rails.root.join("tmp/screenshots/mercury-stepper")
      FileUtils.mkdir_p(directory)
      page.save_screenshot(directory.join("#{name}.png"))
    end

  def capture_class_review(name, width, height)
    page.current_window.resize_to(width, height)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    return unless ENV["SETUP_SCREENSHOTS"]

    directory = Rails.root.join("tmp/screenshots/class-review")
    FileUtils.mkdir_p(directory)
    page.save_screenshot(directory.join("#{name}.png"))
  end

    def sign_in_as_leader_in_browser
      leader = people(:grace_leader)
      Project.create_for(creator: leader, attributes: { name: "Planner Test Project" }) unless Policy.can?(leader, :create, Project)
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
