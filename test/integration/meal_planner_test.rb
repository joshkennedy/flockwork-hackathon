require "test_helper"

class MealPlannerTest < ActionDispatch::IntegrationTest
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @provider = Planner::Providers::Fake.new([])
    Rails.configuration.x.planner_provider = @provider
    sign_in_as_leader
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
  end

  test "starting a meal train opens one form without AI or creating slots" do
    assert_no_enqueued_jobs only: PlannerStepJob do
      assert_difference [ "Project.count", "PlannerSession.count" ], 1 do
        post start_meal_planner_projects_path
      end
    end
    session = PlannerSession.order(:id).last!
    assert_equal 4, session.flow_version
    assert_empty session.project.slots
    follow_redirect!
    assert_select "input[name='meal_setup[label]'][value='Dinner']"
    assert_select "input[name='meal_setup[start_date]'][required]"
    assert_no_match(/Finish with This|Save and Leave|The planner sees|Answer in your own words|Project Details/, response.body)
    assert_empty @provider.contexts
  end

  test "partial details save as a resumable draft and never create work" do
    project, session = start_setup
    assert_no_difference "Slot.count" do
      save_setup(project, session, name: "Meals for November", start_date: "")
    end
    assert_response :success
    assert_equal false, response.parsed_body.fetch("addable")
    assert_equal "Meals for November", project.reload.name
    assert_equal "", session.reload.meal_setup.fetch("start_date")
    assert_empty session.pending_items
    get project_path(project)
    assert_select "a[href=?]", project_planner_session_path(project, session), text: "Finish Meal Setup"
    get project_planner_session_path(project, session)
    assert_select "input[name='meal_setup[name]'][value='Meals for November']"
    assert_empty @provider.contexts
  end

  test "clearing a name saves a quiet draft but still requires a name before adding meals" do
    project, session = start_setup
    original_name = project.name
    save_setup(project, session, name: "", days: "5")
    assert_response :success
    assert_equal false, response.parsed_body.fetch("addable")
    assert_equal "", session.reload.meal_setup.fetch("name")
    assert_match "5 meal slots", response.parsed_body.fetch("preview")
    assert_equal original_name, project.reload.name
    assert_equal 5, session.pending_item_count

    assert_no_difference "Slot.count" do
      post accept_project_planner_session_path(project, session), params: {
        meal_setup: details.merge(name: ""), expected_revision: session.generation_revision
      }
    end
    assert_response :unprocessable_content
    assert_not_predicate session.reload, :accepted?

    save_setup(project, session, name: "A new name", days: "5")
    assert_response :success
    assert_equal "A new name", project.reload.name
    assert_equal true, response.parsed_body.fetch("addable")
    assert_equal 5, session.reload.pending_item_count
  end

  test "structured fields produce dated alternate-day slots without AI" do
    project, session = start_setup
    save_setup(project, session, days: "7", every: "2", capacity: "2", time: "18:30")
    assert_response :success
    assert_equal true, response.parsed_body.fetch("addable")
    assert_equal 4, response.parsed_body.fetch("count")
    assert_match "6:30 PM", response.parsed_body.fetch("preview")
    assert_equal %w[2027-02-15 2027-02-17 2027-02-19 2027-02-21], session.reload.visible_pending_items.map { |item| item.dig("fields", "date") }
    assert_equal [ 2 ], session.visible_pending_items.map { |item| item.dig("fields", "capacity") }.uniq
    assert_empty project.slots
    assert_nil project.starts_on
    assert_empty @provider.contexts
  end

  test "final Add accepts posted details once and arrives at the Sign-up sheet" do
    project, session = start_setup
    save_setup(project, session, name: "February meals")
    values = { meal_setup: details.merge(name: "February meals"), expected_revision: session.generation_revision }
    assert_difference "project.slots.count", 3 do
      post accept_project_planner_session_path(project, session), params: values
    end
    assert_redirected_to project_path(project, added_plan: session.id, anchor: "tool-signup-sheet")
    assert_equal [ "Dinner" ], project.slots.pluck(:label).uniq
    assert_equal Date.new(2027, 2, 15), project.reload.starts_on
    assert_equal Date.new(2027, 2, 17), project.ends_on
    assert_equal "February meals", project.name
    assert_includes project.enabled_tools, "signup_sheet"
    assert_predicate session.reload, :accepted?
    assert_no_difference "Slot.count" do
      post accept_project_planner_session_path(project, session), params: values
    end
    follow_redirect!
    assert_select "[role='status']", text: "3 meals added to your Sign-up sheet."
    assert_empty @provider.contexts
  end

  test "invalid final submission creates no slots and keeps typed values visible" do
    project, session = start_setup
    assert_no_difference "Slot.count" do
      post accept_project_planner_session_path(project, session), params: {
        meal_setup: details.merge(start_date: "", label: "Soup and bread"), expected_revision: session.generation_revision
      }
    end
    assert_response :unprocessable_content
    assert_select "[role='alert']", text: /Start date can't be blank/
    assert_select "input[name='meal_setup[label]'][value='Soup and bread']"
    assert_not_predicate session.reload, :accepted?
  end

  test "invalid structured values leave the saved draft untouched" do
    project, session = start_setup
    original = session.attributes
    [ { days: "61" }, { days: "1.5" }, { every: "0" }, { capacity: "0" }, { time: "25:00" }, { start_date: "not-a-date" } ].each do |invalid|
      save_setup(project, session, invalid)
      assert_response :unprocessable_content
      assert response.parsed_body.fetch("error").present?
      assert_equal original, session.reload.attributes
    end
    assert_empty @provider.contexts
  end

  test "stale saves and final submissions cannot replace newer work" do
    project, session = start_setup
    revision = session.generation_revision
    save_setup(project, session, label: "Lunch")
    patch meal_setup_project_planner_session_path(project, session), params: {
      meal_setup: details, expected_revision: revision
    }, as: :json
    assert_response :conflict
    assert_match(/another tab/, response.parsed_body.fetch("error"))
    assert_equal "Lunch", session.reload.meal_setup.fetch("label")
    assert_no_difference "Slot.count" do
      post accept_project_planner_session_path(project, session), params: { meal_setup: details, expected_revision: revision }
    end
    assert_response :see_other
    assert_equal "Lunch", session.reload.meal_setup.fetch("label")
  end

  test "edits and removals survive bulk changes and conflicts block acceptance" do
    project, session = start_setup
    save_setup(project, session)
    first, second = session.reload.visible_pending_items
    session.edit_pending_item!(id: first.fetch("id"), fields: { label: "Soup" }, expected_revision: session.generation_revision)
    session.remove_pending_item!(id: second.fetch("id"), expected_revision: session.generation_revision)
    save_setup(project, session, label: "Lunch")
    assert_equal false, response.parsed_body.fetch("addable")
    assert_equal "Soup", session.reload.visible_pending_items.first.dig("fields", "label")
    assert session.pending_items.second.fetch("removed")
    session.resolve_pending_conflict!(id: first.fetch("id"), choice: "keep_edit", expected_revision: session.generation_revision)
    assert_difference "project.slots.count", 2 do
      post accept_project_planner_session_path(project, session), params: {
        meal_setup: details.merge(label: "Lunch"), expected_revision: session.generation_revision
      }
    end
    assert_equal %w[Soup Lunch], project.slots.order(:date).pluck(:label)
  end

  test "keeping an edited occurrence outside a shortened range remains accepted" do
    project, session = start_setup
    save_setup(project, session)
    last = session.reload.visible_pending_items.last
    session.edit_pending_item!(id: last.fetch("id"), fields: { label: "Soup" }, expected_revision: session.generation_revision)
    save_setup(project, session, days: "1")
    assert_equal "removed_by_revision", session.reload.pending_items.last.dig("conflict", "type")
    session.resolve_pending_conflict!(id: last.fetch("id"), choice: "keep_edit", expected_revision: session.generation_revision)
    assert_difference "project.slots.count", 2 do
      post accept_project_planner_session_path(project, session), params: {
        meal_setup: details.merge(days: "1"), expected_revision: session.generation_revision
      }
    end
    assert_predicate session.reload, :accepted?
  end

  test "saving a row only records changed fields as overrides" do
    project, session = start_setup
    save_setup(project, session)
    first = session.pending_items.first
    session.edit_pending_item!(id: first.fetch("id"), fields: first.fetch("fields").merge("label" => "Soup"), expected_revision: session.generation_revision)
    assert_equal({ "label" => "Soup" }, session.reload.pending_items.first.fetch("user_edits"))
    save_setup(project, session, capacity: "2")
    assert_equal true, response.parsed_body.fetch("addable")
    assert_equal "Soup", session.reload.pending_items.first.dig("fields", "label")
    assert_equal 2, session.pending_items.first.dig("fields", "capacity")
  end

  test "opening an old meal draft preserves edits and invalidates queued generation" do
    project = projects(:community_meal)
    item = Planner::PendingItems.candidate(source_key: "old-meals:0", fields: {
      "label" => "Dinner", "date" => "2027-02-15", "time" => "17:30", "capacity" => 1
    }, metadata: { "day_offset" => 0 }).to_h
    item["fields"] = item.fetch("fields").merge("label" => "Soup")
    item["user_edits"] = { "label" => "Soup" }
    session = project.planner_sessions.create!(started_by: people(:leader), description: "Meal train", flow_version: 2,
      generation_state: "queued", generation_revision: 2, pending_items: [ item ])
    get project_planner_session_path(project, session)
    assert_response :success
    assert_equal 4, session.reload.flow_version
    assert_equal [ item ], session.pending_items
    assert_equal "Dinner", session.meal_setup.fetch("label")
    assert_equal "idle", session.generation_state
    assert_not session.generate!(revision: 2)
    assert_select "input[name='meal_setup[label]'][value='Dinner']"
    assert_select ".meal-slot", text: /Soup/
    assert_empty @provider.contexts
  end

  test "structured setup rejects generated-answer endpoints" do
    project, session = start_setup
    %i[select_answer continue_planning finish_planning retry_generation].each do |action|
      assert_no_enqueued_jobs only: PlannerStepJob do
        post public_send("#{action}_project_planner_session_path", project, session), params: { answer: "Lunch", expected_revision: session.generation_revision }
      end
      assert_response :not_found
    end
    assert_empty @provider.contexts
  end

  test "volunteers cannot modify or accept setup" do
    project, session = start_setup
    sign_in_as_volunteer
    save_setup(project, session)
    assert_response :not_found
    assert_no_difference "Slot.count" do
      post accept_project_planner_session_path(project, session), params: { meal_setup: details, expected_revision: session.generation_revision }
    end
    assert_response :not_found
  end

  test "no-JavaScript preview saves details without creating slots" do
    project, session = start_setup
    assert_no_difference "Slot.count" do
      post accept_project_planner_session_path(project, session), params: {
        meal_setup: details, expected_revision: session.generation_revision, preview: "true"
      }
    end
    follow_redirect!
    assert_select ".meal-slot", count: 3
    assert_select "input[type='submit'][value='Add 3 Meal Slots']:not([disabled])"
  end

  test "changing fields without autosave requires reviewing the new count before Add" do
    project, session = start_setup
    save_setup(project, session)
    values = { meal_setup: details.merge(days: "5"), expected_revision: session.generation_revision }
    assert_no_difference "Slot.count" do
      post accept_project_planner_session_path(project, session), params: values
    end
    follow_redirect!
    assert_select "input[type='submit'][value='Add 5 Meal Slots']:not([disabled])"
    assert_difference "project.slots.count", 5 do
      post accept_project_planner_session_path(project, session), params: values.merge(expected_revision: session.reload.generation_revision)
    end
  end

  private
    def start_setup
      post start_meal_planner_projects_path
      session = PlannerSession.order(:id).last!
      [ session.project, session ]
    end

    def details
      { name: "Meal train", label: "Dinner", start_date: "2027-02-15", days: "3", every: "1", time: "17:30", capacity: "1" }
    end

    def save_setup(project, session, overrides = {})
      patch meal_setup_project_planner_session_path(project, session), params: {
        meal_setup: details.merge(overrides), expected_revision: session.reload.generation_revision
      }, as: :json
      session.reload
    end
end
