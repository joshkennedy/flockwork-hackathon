require "application_system_test_case"

class PlannerSystemTest < ApplicationSystemTestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "a Leader builds and accepts every Planner Suggestion kind" do
    project = Project.create_for(
      creator: people(:grace_leader),
      attributes: {
        name: "Planner System Meal",
        description: "Prepare and serve a neighborhood dinner.",
        starts_on: Date.new(2027, 2, 12),
        ends_on: Date.new(2027, 2, 13),
        enabled_tools: []
      }
    )
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen before guests arrive?",
          "options" => [ "Set the room", "Prepare food", "Welcome volunteers" ]
        }
      ),
      planner_response(
        card: {
          "question" => "What final detail should the plan include?",
          "options" => [ "A rain plan", "A cleanup plan", "A welcome plan" ]
        },
        added: [
          suggestion(
            "task",
            "title" => "Set welcome tables",
            "details" => "Place signs and name tags.",
            "due_in_days" => 0,
            "role" => "2 setup volunteers"
          )
        ]
      ),
      planner_response(
        finished: true,
        added: [
          suggestion("enable_tool", "tool" => "docs"),
          suggestion(
            "schedule_item",
            "title" => "Volunteer huddle",
            "day_offset" => 0,
            "starts_at" => "16:00",
            "ends_at" => "16:30",
            "location" => "Lobby"
          ),
          suggestion(
            "slot_run",
            "label" => "Meal delivery team",
            "start_day_offset" => 0,
            "end_day_offset" => 1,
            "time" => "17:00",
            "capacity" => 2
          ),
          suggestion(
            "booking",
            "description" => "Overflow room",
            "estimated_dollars" => 275,
            "role" => "1 booking lead"
          ),
          suggestion(
            "purchase",
            "description" => "Welcome signs",
            "estimated_dollars" => 64.50,
            "role" => "1 purchasing lead"
          ),
          suggestion(
            "list",
            "name" => "Serving teams",
            "columns" => [
              { "name" => "Team", "type" => "text" },
              { "name" => "Ready", "type" => "checkbox" }
            ]
          )
        ]
      )
    ])

    sign_in_as_leader_in_browser
    visit project_path(project)
    click_on "Plan More"
    fill_in "Describe this plan in one sentence", with: "Finish the neighborhood meal plan."
    click_on "Start Planning"

    assert_text "What should happen before guests arrive?"
    assert_text "Suggestions will appear here"
    find("body").send_keys("1")

    assert_text "What final detail should the plan include?"
    assert_text "Tasks 1"
    assert_text "Set welcome tables"
    card_path = page.current_path
    within "li.suggestion", text: "Set welcome tables" do
      click_on "Keep"
    end
    assert_current_path card_path
    assert_selector "li.suggestion.kept", text: "Set welcome tables"
    fill_in "Or answer in your own words", with: "Include a cleanup checklist."
    click_on "Answer"

    assert_text "Your plan is ready to review"
    assert_text "Schedule items 1"
    assert_text "Slot runs 1"
    assert_text "Bookings 1"
    assert_text "Purchases 1"
    assert_text "Lists 1"
    within "li.suggestion", text: "Docs & Files" do
      click_on "Drop"
    end
    assert_no_selector "li.suggestion", text: "Docs & Files"
    click_on "Review Suggestions"
    assert_selector "h1", text: "Review Suggestions"
    assert_text "Currently dropped"
    click_button "Accept All", exact: true

    assert_current_path project_path(project)
    assert_text "Meal delivery team", count: 2
    click_on "Tasks"
    assert_text "Set welcome tables"
    assert_no_text "Meal delivery team"
    # Every accepted item lands somewhere; the rest sit in tabs not shown right now.
    [ "Volunteer huddle", "Overflow room", "Welcome signs", "Serving teams", "Ready" ].each { |text| assert_text :all, text }
  end

  private
    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end

    def planner_response(card: nil, finished: false, added: [], removed_ids: [])
      Planner::Response.new(card:, finished:, added:, removed_ids:)
    end

    def suggestion(kind, fields)
      {
        "kind" => kind,
        "fields" => fields
      }
    end
end
