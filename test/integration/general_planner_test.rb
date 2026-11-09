require "test_helper"

class GeneralPlannerTest < ActionDispatch::IntegrationTest
  class FakeVoiceClientSecretMinter
    def call = "general-planner-voice-secret"
  end

  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_voice_client_secret_minter = Rails.configuration.x.voice_client_secret_minter
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Rails.configuration.x.voice_client_secret_minter = @original_voice_client_secret_minter
  end

  test "each general planning kind starts a new v3 shell asynchronously without changing existing projects" do
    sign_in_as_leader
    existing = projects(:community_meal)
    original = existing.attributes

    expected_names = {
      "retreat" => "Retreat",
      "workday" => "Workday",
      "children_program" => "Children’s program",
      "class" => "Class",
      "other" => "Outreach project"
    }

    expected_names.each_key do |planning_kind|
      use_provider(response(card: card("What matters most?")))
      params = { planning_kind: }
      params[:planner_session] = { description: "Organize an outreach project." } if planning_kind == "other"

      assert_enqueued_with(job: PlannerStepJob) do
        assert_difference [ "Project.count", "PlannerSession.count" ], 1 do
          post start_planner_projects_path, params:
        end
      end

      planner_session = PlannerSession.order(:id).last!
      assert_response :see_other
      assert_redirected_to project_planner_session_path(planner_session.project, planner_session)
      assert_equal 3, planner_session.flow_version
      assert_equal planning_kind, planner_session.planning_kind
      assert_equal expected_names.fetch(planning_kind), planner_session.project.name
      assert_equal "queued", planner_session.generation_state
      assert_empty planner_session.project.enabled_tools
    end

    assert_equal original, existing.reload.attributes

    assert_no_enqueued_jobs only: PlannerStepJob do
      assert_no_difference [ "Project.count", "PlannerSession.count" ] do
        post start_planner_projects_path, params: { planning_kind: "not-a-kind" }
      end
    end
    assert_response :bad_request
  end

  test "Class appears in the chooser and starts with class-specific planning guidance" do
    sign_in_as_leader

    get new_project_path

    assert_response :success
    assert_select "form[action='#{start_planner_projects_path}']" do
      assert_select "input[name='planning_kind'][value='class']"
      assert_select "button", text: /Class/
      assert_select "svg"
    end

    class_kind = Planner::ProjectKinds::CHOICES.fetch("class")
    assert_equal "Class", class_kind.fetch(:name)
    assert_equal "Plan a class series with teachers, food, and take-home materials.", class_kind.fetch(:description)
    assert_match(/how many sessions/, class_kind.fetch(:prompt))
    assert_match(/date of each session/, class_kind.fetch(:prompt))
    assert_match(/Teacher, Session 3/, class_kind.fetch(:prompt))
    assert_match(/food or catering/, class_kind.fetch(:prompt))
    assert_match(/take-home materials/, class_kind.fetch(:prompt))
    assert_match(/without asking for names or private details/, class_kind.fetch(:prompt))
    assert_match(/schedule_item_source_key/, class_kind.fetch(:prompt))
    assert_no_match(/cannot yet link/, class_kind.fetch(:prompt))
  end

  test "Something Else collects a description and redacts names before the first Planner card" do
    provider = use_provider(response(card: card("What should the plan include?")))
    sign_in_as_leader

    get new_project_path(planning_kind: "other")
    assert_response :success
    assert_select "form[action='#{start_planner_projects_path}']" do
      assert_select "input[name='planner_session[description]']"
    end

    assert_no_difference [ "Project.count", "PlannerSession.count" ] do
      post start_planner_projects_path, params: {
        planning_kind: "other", planner_session: { description: "" }
      }
    end
    assert_response :unprocessable_content
    assert_select "[role='alert']", text: /Describe what you're organizing/

    perform_enqueued_jobs(only: PlannerStepJob) do
      post start_planner_projects_path, params: {
        planning_kind: "other",
        planner_session: { description: "Leo Leader is organizing a neighborhood cleanup." }
      }
    end

    planner_session = PlannerSession.order(:id).last!
    assert_equal "Leo Leader is organizing a neighborhood cleanup.", planner_session.description
    assert_equal "[name] is organizing a neighborhood cleanup.", provider.contexts.sole.fetch("project_intent")
    assert_equal "What should the plan include?", planner_session.reload.current_card.fetch("question")
  end

  test "a full snapshot previews and atomically accepts every provider item kind with explicit dates" do
    use_provider(
      response(card: card("What should this day accomplish?")),
      response(card: nil, finished: true, added: all_provider_items)
    )
    sign_in_as_leader
    project, planner_session = start_and_generate("workday")

    select_and_generate(project, planner_session, "Repair the playground")
    assert_equal %w[slot slot task schedule_item booking purchase list enable_tool],
      planner_session.reload.visible_pending_items.pluck("kind")

    post finish_planning_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision
    }
    assert_predicate planner_session.reload, :reviewing?

    get project_planner_session_path(project, planner_session)
    assert_select "form[action=?] input[name='project[name]'][value='Workday']",
      accept_project_planner_session_path(project, planner_session)

    assert_difference "project.slots.count", 2 do
      assert_difference "project.tasks.count", 1 do
        assert_difference "project.schedule_items.count", 1 do
          assert_difference "project.budget_lines.count", 2 do
            assert_difference "project.lists.count", 1 do
              post accept_project_planner_session_path(project, planner_session), params: {
                expected_revision: planner_session.generation_revision,
                project: { name: "Playground repair day" }
              }
            end
          end
        end
      end
    end

    assert_response :see_other
    assert_redirected_to project_path(project, added_plan: planner_session.id, anchor: "tool-signup-sheet")
    assert_equal "Playground repair day", project.reload.name
    assert_equal "signup_sheet", planner_session.reload.acceptance_tool
    assert_equal Date.new(2027, 4, 11), project.tasks.find_by!(title: "Confirm volunteers").due_on
    assert_equal Date.new(2027, 4, 10), project.schedule_items.find_by!(title: "Morning briefing").date
    assert_equal %w[booking purchase], project.budget_lines.order(:id).pluck(:kind)
    assert_equal [ [ "Item", "text" ], [ "Packed", "checkbox" ] ],
      project.lists.find_by!(name: "Supply checklist").columns.order(:id).pluck(:name, :column_type)
    assert_equal %w[budget docs list schedule signup_sheet tasks], project.reload.enabled_tools.sort
  end

  test "acceptance preserves a Project name the Leader already saved" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "workday",
      items: [ item("task", "task-1", title: "Set out tools", details: "", due_on: nil) ]
    )
    project.update!(name: "Neighborhood serve day")

    post accept_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      project: { name: project.name }
    }

    assert_response :see_other
    assert_equal "Neighborhood serve day", project.reload.name
  end

  test "direct edits removals and restores survive a changed answer and safe resume" do
    revised = all_provider_items.deep_dup
    revised.find { |item| item["kind"] == "task" }["fields"]["title"] = "AI changed this title"
    revised.find { |item| item["kind"] == "schedule_item" }["fields"]["location"] = "West entrance"
    use_provider(
      response(card: card("What should this day accomplish?")),
      response(card: card("Who is helping?"), added: all_provider_items),
      response(card: card("Who is helping?"), added: revised)
    )
    sign_in_as_leader
    project, planner_session = start_and_generate("workday")
    select_and_generate(project, planner_session, "Repair the playground")
    task = planner_session.visible_pending_items.find { |item| item["kind"] == "task" }
    schedule = planner_session.visible_pending_items.find { |item| item["kind"] == "schedule_item" }

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: { id: task.fetch("id"), decision: "edit", fields: {
        title: "Call the volunteer team", details: "Confirm the morning crew.", due_on: "2027-04-09"
      } }
    }
    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision,
      item: { id: schedule.fetch("id"), decision: "remove" }
    }
    assert_not_includes planner_session.reload.visible_pending_items.pluck("id"), schedule.fetch("id")

    post select_answer_project_planner_session_path(project, planner_session), params: {
      answer: "Repair the playground safely", expected_revision: planner_session.generation_revision, step_index: 0
    }
    perform_enqueued_jobs(only: PlannerStepJob)
    items = planner_session.reload.pending_items.index_by { |item| item.fetch("id") }
    assert_equal "Call the volunteer team", items.fetch(task.fetch("id")).dig("fields", "title")
    assert_equal "2027-04-09", items.fetch(task.fetch("id")).dig("fields", "due_on")
    assert_equal true, items.fetch(schedule.fetch("id")).fetch("removed")

    post save_and_leave_project_planner_session_path(project, planner_session)
    assert_redirected_to project_path(project)
    get project_planner_session_path(project, planner_session)
    assert_response :success
    assert_select "input[value='Call the volunteer team']"

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision,
      item: { id: schedule.fetch("id"), decision: "restore" }
    }
    assert_includes planner_session.reload.visible_pending_items.pluck("id"), schedule.fetch("id")
  end

  test "unknown budget and missing dates block the whole acceptance transaction" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "retreat",
      items: [
        item("task", "task-1", title: "Reserve rooms", details: "", due_on: nil),
        item("booking", "booking-1", description: "Retreat center", estimated_dollars: nil),
        item("schedule_item", "schedule-1", title: "Opening", date: nil, starts_at: "09:00", ends_at: "09:30", location: "Hall")
      ]
    )

    assert_no_difference [ -> { project.tasks.count }, -> { project.budget_lines.count }, -> { project.schedule_items.count } ] do
      post accept_project_planner_session_path(project, planner_session), params: {
        expected_revision: planner_session.generation_revision
      }
    end
    assert_response :see_other
    assert_match(/Estimated cost is required/, flash[:alert])
    assert_match(/Date can't be blank/, flash[:alert])
    assert_predicate planner_session.reload, :reviewing?
  end

  test "review identifies and links to the field blocking acceptance" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "retreat",
      items: [
        item("booking", "booking-1", description: "Retreat center", estimated_dollars: nil),
        item("schedule_item", "schedule-1", title: "Opening", date: nil, starts_at: "09:00", ends_at: "09:30", location: "Hall")
      ]
    )
    budget_item, schedule_item = planner_session.visible_pending_items
    budget_item_id = "pending-item-#{budget_item.fetch("id")}"
    budget_field_id = "pending_#{budget_item.fetch("id")}_estimated_dollars"
    budget_error_id = "#{budget_field_id}_error"
    schedule_item_id = "pending-item-#{schedule_item.fetch("id")}"
    schedule_field_id = "pending_#{schedule_item.fetch("id")}_date"
    schedule_error_id = "#{schedule_field_id}_error"
    note_id = ActionView::RecordIdentifier.dom_id(planner_session, :add_note)

    get project_planner_session_path(project, planner_session)

    assert_response :success
    assert_select "button[disabled][aria-describedby=?]", note_id, text: "Add to Project"
    assert_select "p##{note_id} a[href='##{budget_item_id}'][data-turbo='false']", text: "1 budget line needs an estimated cost"
    assert_select "p##{note_id} a[href='##{schedule_item_id}'][data-turbo='false']", text: "1 schedule item needs a date"
    assert_select "article##{budget_item_id}.meal-slot-error details[open]"
    assert_select "input##{budget_field_id}[aria-invalid='true'][aria-describedby=?]", budget_error_id
    assert_select "p##{budget_error_id}", text: "Estimated cost is required"
    assert_select "article##{schedule_item_id}.meal-slot-error details[open]"
    assert_select "input##{schedule_field_id}[aria-invalid='true'][aria-describedby=?]", schedule_error_id
    assert_select "p##{schedule_error_id}", text: "Date can't be blank"
  end

  test "review links the start-date blocker to its invalid field" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "workday",
      items: [ item("task", "task-1", title: "Confirm crew", details: "", due_in_days: -1) ]
    )
    note_id = ActionView::RecordIdentifier.dom_id(planner_session, :add_note)
    field_id = "review_date_starts_on"

    get project_planner_session_path(project, planner_session)

    assert_response :success
    assert_select "button[disabled][aria-describedby=?]", note_id, text: "Add to Project"
    assert_select "label[for='#{field_id}']", text: "Project start date"
    assert_select "input##{field_id}.field-error[aria-invalid='true']"
    assert_select "p##{note_id} a[href='##{field_id}'][data-turbo='false']",
      text: "Set the start date above to add these items."
  end

  test "setting the first Project start date preserves explicit item dates and a cleared due date" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "workday",
      items: [
        item("task", "task-1", title: "Confirm crew", details: "", due_on: "2027-04-11"),
        item("schedule_item", "schedule-1", title: "Briefing", date: "2027-04-10", starts_at: "09:00", ends_at: "09:30", location: "Hall"),
        item("slot_run", "crew", label: "Work crew", start_date: "2027-04-10", end_date: "2027-04-11", time: "10:00", capacity: 2)
      ]
    )

    task = planner_session.visible_pending_items.find { |pending| pending["kind"] == "task" }
    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: { id: task.fetch("id"), decision: "edit", fields: task.fetch("fields").merge("due_on" => "") }
    }
    patch planning_details_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision,
      project: { name: project.name, starts_on: "2027-04-01" }
    }

    items = planner_session.reload.visible_pending_items
    assert_empty items.find { |pending| pending["kind"] == "task" }.dig("fields", "due_on")
    assert_equal "2027-04-10", items.find { |pending| pending["kind"] == "schedule_item" }.dig("fields", "date")
    assert_equal %w[2027-04-10 2027-04-11], items.select { |pending| pending["kind"] == "slot" }.pluck("fields").pluck("date")
  end

  test "stale acceptance creates nothing and duplicate acceptance is idempotent" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "other",
      items: [ item("task", "task-1", title: "Publish the plan", details: "Final version", due_on: "2027-04-11") ]
    )
    stale_revision = planner_session.generation_revision
    task = planner_session.visible_pending_items.sole
    assert_equal 1, planner_session.visible_pending_items.size
    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: stale_revision,
      item: { id: task.fetch("id"), decision: "edit", fields: task.fetch("fields").merge("title" => "Publish final plan") }
    }

    assert_no_difference -> { project.tasks.count } do
      post accept_project_planner_session_path(project, planner_session), params: { expected_revision: stale_revision }
    end
    assert_match(/changed in another request/, flash[:alert])

    before_count = project.tasks.count
    post accept_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision
    }
    assert_equal before_count + 1, project.tasks.count
    assert_equal "tasks", planner_session.reload.acceptance_tool
    assert_no_difference -> { project.tasks.count } do
      post accept_project_planner_session_path(project, planner_session), params: {
        expected_revision: planner_session.generation_revision
      }
    end
  end

  test "an invalid Slot session reference is shown on the Planner item" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "class",
      items: [
        item("slot_run", "teacher", label: "Teacher, Session 3", start_date: "2027-04-18", end_date: "2027-04-18", time: "09:00", capacity: 1, schedule_item_source_key: "missing-session")
      ]
    )

    get project_planner_session_path(project, planner_session)

    assert_response :success
    assert_select "article.meal-slot-error", text: /Session does not match a planned or existing Schedule item/
    assert_select "button[disabled]", text: "Add to Project"
  end

  test "build-as-you-go planning supports voice while meal setup rejects it" do
    sign_in_as_leader
    Rails.configuration.x.voice_client_secret_minter = FakeVoiceClientSecretMinter.new
    project = projects(:community_meal)
    planner_session = project.planner_sessions.create!(
      started_by: people(:leader),
      description: "Plan the workday.",
      flow_version: 3,
      planning_kind: "workday",
      current_card: card("What matters first?")
    )

    post voice_session_project_planner_session_path(project, planner_session), as: :json

    assert_response :success
    payload = @response.parsed_body
    assert_equal "grok-voice-latest", payload.fetch("model")
    assert_equal "answer_card", payload.fetch("tools").sole.fetch("name")
    assert_includes payload.fetch("instructions"), "What matters first?"
    assert_includes payload.fetch("instructions"), "Project preview updates on screen"

    meal_setup = project.planner_sessions.create!(
      started_by: people(:leader),
      description: "Plan the meals.",
      flow_version: 4,
      planning_kind: "meal_train"
    )
    post voice_session_project_planner_session_path(project, meal_setup), as: :json

    assert_response :not_found
  end

  test "general planning enforces leader tenant privacy and legacy endpoint boundaries while v1 remains compatible" do
    provider = use_provider(
      response(card: card("What support is needed?")),
      response(card: card("What happens next?"))
    )
    sign_in_as_leader
    perform_enqueued_jobs(only: PlannerStepJob) do
      post start_planner_projects_path, params: { planning_kind: "children_program" }
    end
    planner_session = PlannerSession.order(:id).last!
    project = planner_session.project
    select_and_generate(project, planner_session, "Leo Leader will coordinate")
    assert_not_includes JSON.generate(provider.contexts.last), "Leo Leader"

    post answer_project_planner_session_path(project, planner_session), params: { answer: "Private answer" }
    assert_response :not_found
    patch suggestion_project_planner_session_path(project, planner_session), params: {
      suggestion: { id: "anything", decision: "keep" }
    }
    assert_response :not_found
    post skip_to_review_project_planner_session_path(project, planner_session)
    assert_response :not_found
    get review_project_planner_session_path(project, planner_session)
    assert_redirected_to project_planner_session_path(project, planner_session)

    delete session_path
    sign_in_as_volunteer
    post start_planner_projects_path, params: { planning_kind: "workday" }
    assert_response :see_other
    assert_equal people(:volunteer), PlannerSession.order(:id).last!.started_by
    get project_planner_session_path(project, planner_session)
    assert_response :not_found

    delete session_path
    sign_in_as_outsider
    get project_planner_session_path(project, planner_session)
    assert_response :not_found

    delete session_path
    sign_in_as_leader
    legacy_project = projects(:community_meal)
    use_provider(response(card: nil, finished: true, added: [ legacy_task ]))
    post project_planner_sessions_path(legacy_project), params: {
      planner_session: { description: "Prepare the room." }
    }
    legacy = legacy_project.planner_sessions.order(:id).last!
    assert_equal 1, legacy.flow_version
    assert_predicate legacy, :reviewing?
    assert_difference "legacy_project.tasks.count", 1 do
      post accept_project_planner_session_path(legacy_project, legacy), params: { mode: "all" }
    end
  end

  private
    def start_and_generate(planning_kind)
      perform_enqueued_jobs(only: PlannerStepJob) do
        post start_planner_projects_path, params: { planning_kind: }
      end
      planner_session = PlannerSession.order(:id).last!
      [ planner_session.project, planner_session.reload ]
    end

    def select_and_generate(project, planner_session, answer)
      perform_enqueued_jobs(only: PlannerStepJob) do
        post select_answer_project_planner_session_path(project, planner_session), params: {
          answer:, expected_revision: planner_session.reload.generation_revision
        }
      end
      planner_session.reload
    end

    def build_reviewing_session(planning_kind:, items:)
      project = Project.create_for(creator: people(:leader), attributes: {
        name: "Draft project", description: "General planning test", starts_on: nil, enabled_tools: []
      })
      expanded = Planner::PendingItems.expand(items, project:)
      planner_session = project.planner_sessions.create!(
        started_by: people(:leader), flow_version: 3, planning_kind:,
        description: "Plan this project", status: :reviewing,
        pending_items: expanded.map(&:to_h), generation_state: "idle"
      )
      [ project, planner_session ]
    end

    def use_provider(*responses)
      Planner::Providers::Fake.new(responses).tap { |provider| Rails.configuration.x.planner_provider = provider }
    end

    def response(card:, finished: false, added: [])
      Planner::Response.new(card:, finished:, added:, removed_ids: [])
    end

    def card(question, *options)
      choices = options.presence || [ "Safety", "Hospitality", "Shared ownership" ]
      choices << "Something else" while choices.size < 3
      { "question" => question, "options" => choices.take(5) }
    end

    def all_provider_items
      [
        item("slot_run", "crew-slots", label: "Work crew", start_date: "2027-04-10", end_date: "2027-04-11", time: "09:00", capacity: 4),
        item("task", "confirm-volunteers", title: "Confirm volunteers", details: "Call the crew.", due_on: "2027-04-11"),
        item("schedule_item", "morning-briefing", title: "Morning briefing", date: "2027-04-10", starts_at: "08:30", ends_at: "09:00", location: "Main entrance"),
        item("booking", "dumpster", description: "Dumpster rental", estimated_dollars: 250),
        item("purchase", "paint", description: "Paint and brushes", estimated_dollars: 125.50),
        item("list", "supplies", name: "Supply checklist", columns: [ { name: "Item", type: "text" }, { name: "Packed", type: "checkbox" } ]),
        item("enable_tool", "docs", tool: "docs")
      ]
    end

    def item(kind, source_key, **fields)
      { "kind" => kind, "source_key" => source_key, "fields" => fields.stringify_keys }
    end

    def legacy_task
      { "kind" => "task", "fields" => { "title" => "Set the table", "details" => "Put out plates." } }
    end
end
