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

  test "planning details saves a title into the builder field without changing the start date" do
    sign_in_as_leader
    use_provider(response(card: card("What matters most?")))
    post start_planner_projects_path, params: { planning_kind: "class" }
    perform_enqueued_jobs
    planner_session = PlannerSession.order(:id).last!
    project = planner_session.project
    project.update!(starts_on: Date.new(2027, 4, 1))

    patch planning_details_project_planner_session_path(project, planner_session), params: {
      project: { name: "Sunday class" }, expected_revision: planner_session.generation_revision
    }
    assert_response :see_other
    follow_redirect!
    assert_select "input.meal-setup-name[aria-label='Project name'][value='Sunday class']"
    assert_select ".meal-builder-rename", count: 0
    assert_equal "Sunday class", project.reload.name
    assert_equal Date.new(2027, 4, 1), project.starts_on
  end

  test "each general planning kind starts a new v3 shell asynchronously without changing existing projects" do
    sign_in_as_leader
    existing = projects(:community_meal)
    original = existing.attributes

    expected_names = {
      "potluck" => "Potluck or Picnic",
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
      assert_equal [ "messages" ], planner_session.project.enabled_tools

      get project_planner_session_path(planner_session.project, planner_session)
      assert_select "[data-meal-planner-target='status']", count: 1, text: "Drafting your plan…"
      assert_select ".meal-preview-empty", count: 0
      assert_select ".meal-building .meal-skeleton", count: 3
    end

    assert_equal original, existing.reload.attributes

    assert_no_enqueued_jobs only: PlannerStepJob do
      assert_no_difference [ "Project.count", "PlannerSession.count" ] do
        post start_planner_projects_path, params: { planning_kind: "not-a-kind" }
      end
    end
    assert_response :bad_request
  end

  test "project creation shows the three setup steps with the kind chooser current" do
    sign_in_as_leader
    get new_project_path

    assert_select "ol.setup-steps" do
      assert_select "li", count: 3
      assert_select "li[aria-current='step'] h2", text: "What are you organizing?"
      assert_select "li[data-step-state='upcoming'] h2", text: "Answer a few questions"
      assert_select "li[data-step-state='upcoming'] h2", text: "Review and add"
    end
    assert_select ".project-kind-list > details.project-kind-other:first-child" do
      assert_select "summary", text: "Something Else"
    end
    assert_select "details.project-kind-other[open]", count: 0
  end

  test "Class appears in the chooser and starts with class-specific planning guidance" do
    sign_in_as_leader

    get new_project_path

    assert_response :success
    assert_select "form[action='#{start_planner_projects_path}']" do
      assert_select "input[name='planning_kind'][value='class']"
      assert_select "button", text: /Class/
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
    assert_equal({
      "class" => "First class date",
      "potluck" => "Gathering date",
      "retreat" => "Retreat date",
      "workday" => "Workday date",
      "children_program" => "Program start date",
      "other" => "Start date"
    }, Planner::ProjectKinds::CHOICES.transform_values { |choice| choice.fetch(:date_label) }.except("meal_train"))
  end

  test "Potluck or Picnic appears in the chooser with food and helper planning guidance" do
    sign_in_as_leader

    get new_project_path

    assert_response :success
    assert_select ".project-kind-list > details.project-kind-other:first-child", text: /Something Else/
    assert_select "form[action='#{start_planner_projects_path}']" do
      assert_select "input[name='planning_kind'][value='potluck']"
      assert_select "button", text: /Potluck or Picnic/
    end

    potluck = Planner::ProjectKinds::CHOICES.fetch("potluck")
    assert_equal "Potluck or Picnic", potluck.fetch(:name)
    assert_equal "Plan a potluck or picnic together.", potluck.fetch(:description)
    assert_match(/expected headcount/, potluck.fetch(:prompt))
    assert_match(/setting/, potluck.fetch(:prompt))
    assert_match(/main dishes, sides, desserts, and drinks/, potluck.fetch(:prompt))
    assert_match(/practical capacity/, potluck.fetch(:prompt))
    assert_match(/claim_prompt "What are you bringing\?"/, potluck.fetch(:prompt))
    assert_match(/setup and cleanup helpers/, potluck.fetch(:prompt))
    assert_match(/supplies, and a schedule/, potluck.fetch(:prompt))
    assert_match(/Never ask for, infer, or include people's names/, potluck.fetch(:prompt))
  end

  test "a Fake potluck plan reviews, edits, and creates prompted food Slots without People data" do
    fake = Planner::Providers::Fake.new do |_context|
      response(card: nil, finished: true, added: potluck_provider_items)
    end
    Rails.configuration.x.planner_provider = fake
    private_person = organizations(:st_example).people.create!(
      name: "Private Potluck Person",
      email: "private-potluck@example.test",
      phone: "+1-555-234-9876"
    )
    sign_in_as_leader

    perform_enqueued_jobs(only: PlannerStepJob) do
      post start_planner_projects_path, params: { planning_kind: "potluck" }
    end

    planner_session = PlannerSession.order(:id).last!
    project = planner_session.project
    assert_predicate planner_session, :reviewing?
    assert_equal "Potluck or Picnic", project.name
    assert_equal "potluck", planner_session.planning_kind
    prompt = Planner::ProjectKinds::CHOICES.fetch("potluck").fetch(:prompt)
    assert_equal Planner::NameRedactor.new(organizations(:st_example)).call(prompt), fake.contexts.sole.fetch("project_intent")
    assert_not_includes fake.contexts.to_json, private_person.name
    assert_not_includes fake.contexts.to_json, private_person.email
    assert_not_includes fake.contexts.to_json, private_person.phone

    get project_planner_session_path(project, planner_session)
    assert_response :success
    assert_select ".setup-step-detail", text: "Potluck or Picnic"
    assert_select "article.planner-pending-row", text: /Main dishes.*6 spots.*Question: What are you bringing\?/m
    assert_select "input[name='item[fields][claim_prompt]'][value='What are you bringing?'][maxlength='120']", count: 4

    main_dishes = planner_session.visible_pending_items.find { |item| item.dig("fields", "label") == "Main dishes" }
    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: {
        id: main_dishes.fetch("id"),
        decision: "edit",
        fields: { claim_prompt: "Which main dish are you bringing?" }
      }
    }
    assert_response :see_other

    patch planning_details_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision,
      project: { starts_on: "2027-06-06" }
    }
    assert_response :see_other

    planner_session.reload
    assert_difference({ "Slot.count" => 6, "ScheduleItem.count" => 1, "BudgetLine.count" => 1 }) do
      post accept_project_planner_session_path(project, planner_session), params: {
        expected_revision: planner_session.generation_revision
      }
    end

    assert_redirected_to project_path(project, added_plan: planner_session.id, anchor: "tool-signup-sheet")
    assert_equal "Which main dish are you bringing?", project.slots.find_by!(label: "Main dishes").claim_prompt
    assert_equal "What are you bringing?", project.slots.find_by!(label: "Desserts").claim_prompt
    assert_nil project.slots.find_by!(label: "Setup helpers").claim_prompt
    assert_includes project.reload.enabled_tools, "signup_sheet"
  end

  test "Something Else collects a description and redacts names before the first Planner card" do
    provider = use_provider(response(card: card("What should the plan include?")))
    sign_in_as_leader

    get new_project_path(planning_kind: "other")
    assert_response :success
    assert_select "details.project-kind-other[open]"
    assert_select "form[action='#{start_planner_projects_path}']" do
      assert_select "input[name='planner_session[description]']"
    end

    assert_no_difference [ "Project.count", "PlannerSession.count" ] do
      post start_planner_projects_path, params: {
        planning_kind: "other", planner_session: { description: "" }
      }
    end
    assert_response :unprocessable_content
    assert_select "details.project-kind-other[open]" do
      assert_select "[role='alert']", text: /Describe what you're organizing/
      assert_select "input[aria-invalid='true']"
    end

    perform_enqueued_jobs(only: PlannerStepJob) do
      post start_planner_projects_path, params: {
        planning_kind: "other",
        planner_session: { description: "Leo Leader is organizing a neighborhood cleanup." }
      }
    end

    planner_session = PlannerSession.order(:id).last!
    assert_equal "Leo Leader is organizing a neighborhood cleanup.", planner_session.description
    assert_equal "Leo Leader is organizing a neighborhood cleanup.", planner_session.project.description
    assert_equal "[name] is organizing a neighborhood cleanup.", provider.contexts.sole.fetch("project_intent")
    assert_equal "What should the plan include?", planner_session.reload.current_card.fetch("question")
  end

  test "Continue appears while drafting and becomes ready after the answer is prepared" do
    use_provider(
      response(card: card("What should this day accomplish?")),
      response(card: card("Who is helping?"), added: all_provider_items)
    )
    sign_in_as_leader
    project, planner_session = start_and_generate("workday")

    get project_planner_session_path(project, planner_session)
    assert_select "ol.setup-steps" do
      assert_select "li[aria-current='step'] .setup-step-title", text: "Answer a few questions"
      assert_select "li[data-step-state='done']" do
        assert_select ".setup-step-title", text: "What are you organizing?"
        assert_select ".setup-step-detail", text: "Workday"
        assert_select ".sr-only", text: "Done:"
      end
      assert_select "li[aria-current='step']", count: 1
    end
    assert_select "button", text: "Continue", count: 0

    post select_answer_project_planner_session_path(project, planner_session), params: {
      answer: "Repair the playground", expected_revision: planner_session.generation_revision
    }
    get project_planner_session_path(project, planner_session)
    assert_select "button.meal-continue-drafting[disabled]", text: "Drafting…"

    perform_enqueued_jobs(only: PlannerStepJob)
    get project_planner_session_path(project, planner_session)
    assert_select "button.btn-primary:not([disabled])", text: "Continue"
    assert_select "button", text: "Finish with This", count: 0
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
    assert_select "li[aria-current='step'] .setup-step-title", text: "Review and add"
    assert_select "li[data-step-state='done']", count: 2
    assert_select "li[data-step-state='done'] .setup-step-detail", text: "1 answer"
    assert_select "li[data-step-state='done'] summary", text: "Change"
    assert_select ".privacy-line", count: 0
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
    assert_equal %w[budget docs list messages schedule signup_sheet tasks], project.reload.enabled_tools.sort
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

  test "a build-as-you-go plan can be discarded while answering or reviewing" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "workday",
      items: [ item("task", "task-1", title: "Set out tools", details: "", due_on: nil) ]
    )
    confirm = "Discard this plan? Nothing will be added to the Project."

    planner_session.update!(status: :asking, current_card: card("What matters next?"))
    get project_planner_session_path(project, planner_session)
    assert_select "form[action='#{abandon_project_planner_session_path(project, planner_session)}'][data-turbo-confirm=?]", confirm do
      assert_select "button", text: "Discard Plan"
    end

    planner_session.update!(status: :reviewing, current_card: nil)
    get project_planner_session_path(project, planner_session)
    assert_select "form[action='#{abandon_project_planner_session_path(project, planner_session)}'][data-turbo-confirm=?]", confirm do
      assert_select "button", text: "Discard Plan"
    end

    assert_no_difference [ -> { project.tasks.count }, -> { project.planner_sessions.count } ] do
      post abandon_project_planner_session_path(project, planner_session)
    end
    assert_response :see_other
    assert_redirected_to project_path(project)
    assert_predicate planner_session.reload, :abandoned?

    follow_redirect!
    assert_select "a", text: "Continue Planning", count: 0
  end

  test "missing dates block the whole acceptance transaction but an unknown budget does not" do
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
    assert_no_match(/Estimated cost is required/, flash[:alert])
    assert_match(/Date can't be blank/, flash[:alert])
    assert_predicate planner_session.reload, :reviewing?
  end

  test "a blank budget estimate saves and stays marked for later" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "retreat",
      items: [ item("booking", "booking-1", description: "Book venue", estimated_dollars: 400) ]
    )
    budget_item = planner_session.visible_pending_items.sole
    field_id = "pending_#{budget_item.fetch('id')}_estimated_dollars"

    get project_planner_session_path(project, planner_session)

    assert_response :success
    assert_select "input##{field_id}[required]", count: 0

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: {
        id: budget_item.fetch("id"),
        decision: "edit",
        fields: { description: "Book overnight venue", estimated_dollars: "" }
      }
    }

    assert_response :see_other
    saved = planner_session.reload.visible_pending_items.sole
    assert_equal "Book overnight venue", saved.dig("fields", "description")
    assert_equal "", saved.dig("fields", "estimated_dollars")

    get project_planner_session_path(project, planner_session)
    assert_select "article#pending-item-#{budget_item.fetch('id')} .badge-need", text: "Estimate later"
  end

  test "review treats an unknown estimate as informational and links to the remaining blocker" do
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
    schedule_item_id = "pending-item-#{schedule_item.fetch("id")}"
    schedule_field_id = "pending_#{schedule_item.fetch("id")}_date"
    schedule_error_id = "#{schedule_field_id}_error"
    note_id = ActionView::RecordIdentifier.dom_id(planner_session, :add_note)

    get project_planner_session_path(project, planner_session)

    assert_response :success
    assert_select "button[disabled][aria-describedby=?]", note_id, text: "Add to Project"
    assert_select "p##{note_id}", text: "Fix the highlighted item to add."
    assert_select "p##{note_id} a", count: 0
    assert_select "article##{budget_item_id} details:not([open])"
    assert_select "article##{budget_item_id} .badge-need", text: "Estimate later"
    assert_select "article##{budget_item_id}.meal-slot-error", count: 0
    assert_select "article##{budget_item_id} [aria-invalid='true']", count: 0
    assert_select "article##{schedule_item_id} details:not([open])"
    assert_select "article##{schedule_item_id} button.badge-need[data-action='comment-thread#openInvalid'][aria-controls='pending-editor-#{schedule_item.fetch("id")}']", text: "Needs details"
    assert_select "article##{schedule_item_id}.meal-slot-error", count: 0
    assert_select "input##{schedule_field_id}[aria-invalid='true'][aria-describedby=?]", schedule_error_id
    assert_select "p##{schedule_error_id}", text: "Date can't be blank"
  end

  test "review names the missing start date beside Add without marking each item invalid" do
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
    assert_select "label[for='#{field_id}']", text: "Workday date"
    assert_select "input##{field_id}"
    assert_select "input##{field_id}[data-action='change->autosave#save']"
    assert_select "input##{field_id}.field-error, input##{field_id}[aria-invalid]", count: 0
    assert_select "p##{note_id}", text: "Set the Workday date above to add these items."
    assert_select "button.badge-need", text: "Needs details", count: 0
    assert_select "h3", text: "Here’s what will be added", count: 0
    assert_select "p", text: "Items are dated from this day.", count: 0
    assert_select "form[data-controller='autosave'] input[data-autosave-target='submit'][value='Save Date']"
    assert_select ".planner-review-actions" do
      assert_select "button.btn-primary", text: "Add to Project"
      assert_select "button.btn-secondary", text: "Save and Leave"
    end
  end

  test "review names the missing start date when an estimate is unknown" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "workday",
      items: [
        item("task", "task-1", title: "Confirm crew", details: "", due_in_days: -1),
        item("booking", "booking-1", description: "Book venue", estimated_dollars: nil)
      ]
    )
    note_id = ActionView::RecordIdentifier.dom_id(planner_session, :add_note)

    get project_planner_session_path(project, planner_session)

    assert_select "button[disabled][aria-describedby=?]", note_id, text: "Add to Project"
    assert_select "p##{note_id}", text: "Set the Workday date above to add these items."
    assert_select "button.badge-need", text: "Needs details", count: 0
    assert_select ".badge-need", text: "Estimate later"
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

  test "review keeps the saved Project start date editable after reload" do
    sign_in_as_leader
    project, planner_session = build_reviewing_session(
      planning_kind: "workday",
      items: [ item("task", "task-1", title: "Confirm crew", details: "", due_in_days: -1) ]
    )

    patch planning_details_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      project: { starts_on: "2027-04-10" }
    }
    assert_response :see_other

    get project_planner_session_path(project, planner_session)
    assert_select "label", text: "Workday date"
    assert_select "input[name='project[starts_on]'][value='2027-04-10']"

    patch planning_details_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision,
      project: { starts_on: "2027-04-12" }
    }
    assert_equal Date.new(2027, 4, 12), project.reload.starts_on
    assert_equal "2027-04-11", planner_session.reload.visible_pending_items.sole.dig("fields", "due_on")
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
    assert_match(/changed in another tab/, flash[:alert])

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
    assert_select "article.planner-pending-row .meal-slot-edit-panel", text: /Session does not match a planned or existing Schedule item/
    assert_select "button[disabled]", text: "Add to Project"
  end

  test "the builder drops a model-written catch-all option because its own Something else tile covers it" do
    sign_in_as_leader
    project = projects(:community_meal)
    planner_session = project.planner_sessions.create!(
      started_by: people(:leader),
      description: "Plan the workday.",
      flow_version: 3,
      planning_kind: "workday",
      current_card: card("What matters first?", "Garden", "Other churches nearby", "Something else…")
    )

    get project_planner_session_path(project, planner_session)

    assert_response :success
    assert_select "button.answer-tile", text: /Garden/
    assert_select "button.answer-tile", text: /Other churches nearby/
    assert_select "button.answer-tile", text: /Something else/, count: 0
    assert_select "summary.answer-tile", text: /Something else/
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
    assert_includes payload.fetch("instructions"), "This Leader may be on a phone"

    Rails.configuration.x.voice_client_secret_minter = -> { raise "voice instructions must not mint a secret" }
    get voice_instructions_project_planner_session_path(project, planner_session), as: :json

    assert_response :success
    refresh_payload = @response.parsed_body
    assert_equal "answer_card", refresh_payload.fetch("tools").sole.fetch("name")
    assert_includes refresh_payload.fetch("instructions"), "What matters first?"
    assert_not refresh_payload.key?("client_secret")

    meal_setup = project.planner_sessions.create!(
      started_by: people(:leader),
      description: "Plan the meals.",
      flow_version: 4,
      planning_kind: "meal_train"
    )
    post voice_session_project_planner_session_path(project, meal_setup), as: :json

    assert_response :not_found
    get voice_instructions_project_planner_session_path(project, meal_setup), as: :json

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
    assert_no_difference [ "Project.count", "PlannerSession.count" ] do
      post start_planner_projects_path, params: { planning_kind: "workday" }
    end
    assert_response :not_found
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

    def potluck_provider_items
      food = [ [ "main-dishes", "Main dishes", 6 ], [ "sides", "Sides", 8 ], [ "desserts", "Desserts", 8 ], [ "drinks", "Drinks", 5 ] ].map do |key, label, capacity|
        item("slot_run", key, label:, start_day_offset: 0, end_day_offset: 0, time: "12:00", capacity:, claim_prompt: "What are you bringing?")
      end
      food + [
        item("slot_run", "setup", label: "Setup helpers", start_day_offset: 0, end_day_offset: 0, time: "10:30", capacity: 3, claim_prompt: nil),
        item("slot_run", "cleanup", label: "Cleanup helpers", start_day_offset: 0, end_day_offset: 0, time: "14:00", capacity: 3, claim_prompt: nil),
        item("schedule_item", "meal", title: "Potluck meal", day_offset: 0, starts_at: "12:00", ends_at: "14:00", location: "To be chosen"),
        item("purchase", "supplies", description: "Plates, cups, napkins, and serving utensils", estimated_dollars: nil)
      ]
    end

    def item(kind, source_key, **fields)
      { "kind" => kind, "source_key" => source_key, "fields" => fields.stringify_keys }
    end

    def legacy_task
      { "kind" => "task", "fields" => { "title" => "Set the table", "details" => "Put out plates." } }
    end
end
