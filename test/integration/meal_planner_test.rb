require "test_helper"

class MealPlannerTest < ActionDispatch::IntegrationTest
  setup do
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
  end

  test "a Leader starts meal planning asynchronously and a selection prepares the preview before Continue" do
    provider = use_provider(
      response(card: card("Which meals should people bring?", "Dinner", "Lunch")),
      response(
        card: card("How long should the meal train run?", "Three days", "One week"),
        added: [ slot_run(label: "Bring dinner") ]
      )
    )
    sign_in_as_leader

    assert_enqueued_with(job: PlannerStepJob) do
      assert_difference [ "Project.count", "PlannerSession.count" ], 1 do
        post start_meal_planner_projects_path
      end
    end

    planner_session = PlannerSession.order(:id).last!
    project = planner_session.project
    assert_response :see_other
    assert_redirected_to project_planner_session_path(project, planner_session)
    assert_equal "queued", planner_session.generation_state
    assert_empty provider.contexts

    perform_enqueued_jobs(only: PlannerStepJob)
    planner_session.reload
    assert_equal "Which meals should people bring?", planner_session.current_card.fetch("question")
    assert_equal "idle", planner_session.generation_state

    assert_enqueued_with(job: PlannerStepJob) do
      post select_answer_project_planner_session_path(project, planner_session), params: {
        answer: "Dinner",
        expected_revision: planner_session.generation_revision
      }
    end
    assert_response :see_other
    assert_equal "Dinner", planner_session.reload.pending_answer.fetch("text")
    assert_equal "queued", planner_session.generation_state

    perform_enqueued_jobs(only: PlannerStepJob)
    planner_session.reload
    assert_equal 3, planner_session.visible_pending_items.size
    assert_equal "Dinner", planner_session.pending_answer.fetch("text")
    assert_equal "How long should the meal train run?", planner_session.prepared_card.fetch("question")
    assert_equal 2, provider.contexts.size

    assert_no_changes -> { provider.contexts.size } do
      post continue_planning_project_planner_session_path(project, planner_session), params: {
        expected_revision: planner_session.generation_revision
      }
    end
    assert_response :see_other
    assert_equal "How long should the meal train run?", planner_session.reload.current_card.fetch("question")
  end

  test "replacing a selection keeps one answer and a stale generation cannot overwrite it" do
    provider = use_provider(
      response(card: card("Which meals?", "Dinner", "Lunch")),
      response(card: card("How long?"), added: [ slot_run(label: "Dinner") ]),
      response(card: card("How long?"), added: [ slot_run(label: "Lunch") ])
    )
    sign_in_as_leader
    project, planner_session = start_and_generate

    old_revision = select_and_generate(project, planner_session, "Dinner")
    post select_answer_project_planner_session_path(project, planner_session), params: {
      answer: "Lunch",
      expected_revision: old_revision
    }
    new_revision = planner_session.reload.generation_revision

    assert_not_equal old_revision, new_revision
    assert_equal [ "Lunch" ], planner_session.steps.pluck("answer")
    assert_not planner_session.generate!(revision: old_revision)
    assert_equal 2, provider.contexts.size

    perform_enqueued_jobs(only: PlannerStepJob)
    planner_session.reload
    assert_equal [ "Lunch" ], planner_session.steps.pluck("answer")
    assert_equal [ "Lunch" ], planner_session.visible_pending_items.map { |item| item.dig("fields", "label") }.uniq
    assert_equal 3, provider.contexts.size

    post continue_planning_project_planner_session_path(project, planner_session), params: {
      expected_revision: old_revision
    }
    assert_response :see_other
    assert_equal "This plan changed in another request. Your latest plan is shown; please try that change again.", flash[:alert]
  end

  test "Continue advances the revision so an old tab cannot select from the previous step" do
    use_provider(
      response(card: card("Which meals?", "Dinner", "Lunch")),
      response(card: card("How long?", "Three days", "One week"), added: [ slot_run(label: "Dinner") ])
    )
    sign_in_as_leader
    project, planner_session = start_and_generate
    old_revision = select_and_generate(project, planner_session, "Dinner")

    post continue_planning_project_planner_session_path(project, planner_session), params: {
      expected_revision: old_revision
    }
    planner_session.reload
    assert_operator planner_session.generation_revision, :>, old_revision
    assert_equal "How long?", planner_session.current_card.fetch("question")

    assert_no_enqueued_jobs only: PlannerStepJob do
      post select_answer_project_planner_session_path(project, planner_session), params: {
        answer: "Lunch", expected_revision: old_revision
      }
    end
    assert_response :see_other
    assert_equal "This plan changed in another request. Your latest plan is shown; please try that change again.", flash[:alert]
    assert_equal [ "Dinner" ], planner_session.reload.steps.pluck("answer")
  end

  test "retrying stalled generation invalidates the abandoned job revision" do
    provider = use_provider(
      response(card: card("Which meals?", "Dinner", "Lunch")),
      response(card: nil, finished: true, added: [ slot_run(label: "Dinner") ])
    )
    sign_in_as_leader
    project, planner_session = start_and_generate

    post select_answer_project_planner_session_path(project, planner_session), params: {
      answer: "Dinner", expected_revision: planner_session.generation_revision
    }
    abandoned_revision = planner_session.reload.generation_revision
    planner_session.update_column(:updated_at, 2.minutes.ago)
    assert_predicate planner_session.reload, :generation_stalled?
    clear_enqueued_jobs

    assert_enqueued_with(job: PlannerStepJob) do
      post retry_generation_project_planner_session_path(project, planner_session), params: {
        expected_revision: abandoned_revision
      }
    end
    retry_revision = planner_session.reload.generation_revision
    assert_operator retry_revision, :>, abandoned_revision
    assert_equal "queued", planner_session.generation_state
    assert_not planner_session.generate!(revision: abandoned_revision)
    assert_equal 1, provider.contexts.size

    perform_enqueued_jobs(only: PlannerStepJob)
    assert_equal "ready", planner_session.reload.generation_state
    assert_equal 2, provider.contexts.size
  end

  test "occurrences can be edited removed restored saved resumed and accepted only once" do
    use_provider(
      response(card: card("Which meals?", "Dinner", "Lunch")),
      response(card: nil, finished: true, added: [ slot_run(label: "Bring dinner") ])
    )
    sign_in_as_leader
    project, planner_session = start_and_generate
    select_and_generate(project, planner_session, "Dinner")
    first, second, third = planner_session.reload.pending_items

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: {
        id: first.fetch("id"), decision: "edit",
        fields: { label: "Bring soup", date: "2027-02-15", time: "18:30", capacity: 2 }
      }
    }
    assert_response :see_other
    assert_equal "Bring soup", planner_session.reload.pending_items.first.dig("fields", "label")

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: { id: second.fetch("id"), decision: "remove" }
    }
    assert_equal 2, planner_session.reload.visible_pending_items.size

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: { id: second.fetch("id"), decision: "restore" }
    }
    assert_equal 3, planner_session.reload.visible_pending_items.size
    assert_equal third.fetch("id"), planner_session.pending_items.third.fetch("id")

    post save_and_leave_project_planner_session_path(project, planner_session)
    assert_response :see_other
    assert_redirected_to project_path(project)
    get project_planner_session_path(project, planner_session)
    assert_response :success
    assert_select "input[value='Bring soup']"

    post finish_planning_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision
    }
    assert_predicate planner_session.reload, :reviewing?

    stale_accept_revision = planner_session.generation_revision
    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: stale_accept_revision,
      item: {
        id: first.fetch("id"), decision: "edit",
        fields: { label: "Bring hearty soup", date: "2027-02-15", time: "18:30", capacity: 2 }
      }
    }
    assert_no_difference "project.slots.count" do
      post accept_project_planner_session_path(project, planner_session), params: {
        expected_revision: stale_accept_revision
      }
    end
    assert_response :see_other
    assert_equal "This plan changed in another request. Your latest plan is shown; please try that change again.", flash[:alert]

    assert_difference "project.slots.count", 3 do
      post accept_project_planner_session_path(project, planner_session), params: {
        expected_revision: planner_session.reload.generation_revision
      }
    end
    assert_response :see_other
    assert_redirected_to project_path(
      project,
      added_plan: planner_session.id,
      anchor: "tool-signup-sheet"
    )
    assert_equal "Bring hearty soup", project.slots.find_by!(date: "2027-02-15").label
    assert_equal "18:30", project.slots.find_by!(date: "2027-02-15").starts_at_time.strftime("%H:%M")

    assert_no_difference "project.slots.count" do
      post accept_project_planner_session_path(project, planner_session), params: {
        expected_revision: planner_session.generation_revision
      }
    end
    assert_response :see_other
  end

  test "Undo restores the most recently removed occurrence rather than array order" do
    use_provider(
      response(card: card("Which meals?", "Dinner", "Lunch")),
      response(card: nil, finished: true, added: [ slot_run(label: "Bring dinner") ])
    )
    sign_in_as_leader
    project, planner_session = start_and_generate
    select_and_generate(project, planner_session, "Dinner")
    first, _second, third = planner_session.reload.pending_items

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision,
      item: { id: third.fetch("id"), decision: "remove" }
    }
    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision,
      item: { id: first.fetch("id"), decision: "remove" }
    }

    get project_planner_session_path(project, planner_session)
    assert_response :success
    assert_select "form[action='#{pending_item_project_planner_session_path(project, planner_session)}']" do
      assert_select "input[name='item[id]'][value='#{first.fetch("id")}']"
      assert_select "button", text: "Undo"
    end

    patch pending_item_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.reload.generation_revision,
      item: { id: first.fetch("id"), decision: "restore" }
    }
    items = planner_session.reload.pending_items.index_by { |item| item.fetch("id") }
    assert_equal false, items.fetch(first.fetch("id")).fetch("removed")
    assert_equal true, items.fetch(third.fetch("id")).fetch("removed")
  end

  test "acceptance requires dated visible work and only a Leader may plan" do
    use_provider(response(card: nil, finished: true, added: [ undated_slot_run ]))
    sign_in_as_leader
    project, planner_session = start_and_generate
    planner_session.finish_preview!(expected_revision: planner_session.generation_revision)

    assert_no_difference "project.slots.count" do
      post accept_project_planner_session_path(project, planner_session), params: {
        expected_revision: planner_session.generation_revision
      }
    end
    assert_response :see_other
    assert_match(/Date can't be blank/, flash[:alert])
    assert_predicate planner_session.reload, :reviewing?

    sign_in_as_volunteer
    post select_answer_project_planner_session_path(project, planner_session), params: {
      answer: "Dinner", expected_revision: planner_session.generation_revision
    }
    assert_response :not_found
  end

  test "a typed answer is the selected answer in the question and prepares the next step like a tile pick" do
    use_provider(
      response(card: card("Which meals?", "Dinner", "Lunch")),
      response(card: card("How long?"), added: [ slot_run(label: "Breakfast burritos") ])
    )
    sign_in_as_leader
    project, planner_session = start_and_generate

    select_and_generate(project, planner_session, "Breakfast burritos on Saturdays")
    planner_session.reload
    assert_equal "Breakfast burritos on Saturdays", planner_session.pending_answer.fetch("text")
    assert_predicate planner_session, :ready_to_continue?

    get project_planner_session_path(project, planner_session)
    assert_select "p", text: "Your answer: Breakfast burritos on Saturdays"
    assert_select "details[open] textarea, details[open] input[name='answer'][value=?]", "Breakfast burritos on Saturdays"
    assert_select "button[aria-pressed=true]", count: 0
    assert_select "p", text: "Question 1 of 3"

    post continue_planning_project_planner_session_path(project, planner_session), params: {
      expected_revision: planner_session.generation_revision
    }
    planner_session.reload
    assert_equal "How long?", planner_session.current_card.fetch("question")
    assert_nil planner_session.pending_answer
  end

  test "a blank typed answer is a visible alert, not a silent failure" do
    use_provider(response(card: card("Which meals?", "Dinner", "Lunch")))
    sign_in_as_leader
    project, planner_session = start_and_generate

    assert_no_enqueued_jobs only: PlannerStepJob do
      post select_answer_project_planner_session_path(project, planner_session), params: {
        answer: "   ", expected_revision: planner_session.generation_revision
      }
    end
    assert_redirected_to project_planner_session_path(project, planner_session)
    assert_equal "Answer can't be blank", flash[:alert]
    assert_nil planner_session.reload.pending_answer
  end

  test "the meal review asks for the first meal date inline and Add to Project is described by its hint" do
    use_provider(response(card: nil, finished: true, added: [ undated_slot_run ]))
    sign_in_as_leader
    project, planner_session = start_and_generate
    planner_session.finish_preview!(expected_revision: planner_session.generation_revision)

    get project_planner_session_path(project, planner_session)
    hint_id = ActionView::RecordIdentifier.dom_id(planner_session, :add_note)
    assert_select "section.meal-builder-guide form[action=?] input[name='project[starts_on]'][required]",
      planning_details_project_planner_session_path(project, planner_session)
    assert_select "button[disabled][aria-describedby=?]", hint_id, text: "Add to Project"
    assert_select "p##{hint_id}", text: "Set the first meal date above to add these slots."

    patch planning_details_project_planner_session_path(project, planner_session), params: {
      project: { starts_on: "2027-02-14" }, expected_revision: planner_session.generation_revision
    }
    assert_redirected_to project_planner_session_path(project, planner_session)
    get project_planner_session_path(project, planner_session)
    assert_select "section.meal-builder-guide form[action=?]", accept_project_planner_session_path(project, planner_session), count: 1
    assert_select "section.meal-builder-guide button[disabled]", count: 0
  end

  test "legacy Planner sessions keep their original HTTP completion path" do
    use_provider(response(card: nil, finished: true, added: [ task_suggestion ]))
    sign_in_as_leader
    project = projects(:community_meal)

    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Prepare the room before dinner." }
    }
    planner_session = project.planner_sessions.order(:id).last!

    assert_equal 1, planner_session.flow_version
    assert_predicate planner_session, :reviewing?
    assert_redirected_to review_project_planner_session_path(project, planner_session)

    assert_difference "project.tasks.count", 1 do
      post accept_project_planner_session_path(project, planner_session), params: { mode: "all" }
    end
    assert_redirected_to project_path(project)
    assert project.tasks.exists?(title: "Set the table")
  end


  test "a provider outage keeps the answers and offers a calm way to keep going by hand" do
    use_provider(
      response(card: card("Which meals should people bring?", "Dinner", "Lunch")),
      RuntimeError.new("OpenRouter is unavailable")
    )
    sign_in_as_leader
    post start_meal_planner_projects_path
    planner_session = PlannerSession.order(:id).last!
    project = planner_session.project
    perform_enqueued_jobs(only: PlannerStepJob)

    post select_answer_project_planner_session_path(project, planner_session),
      params: { answer: "Dinner", expected_revision: planner_session.reload.generation_revision }
    perform_enqueued_jobs(only: PlannerStepJob)

    planner_session.reload
    assert_equal "failed", planner_session.generation_state
    assert_equal [ "Dinner" ], planner_session.steps.map { |step| step["answer"] }

    get project_planner_session_path(project, planner_session)
    assert_select "[role='alert'] p", text: PlannerSession::ERROR_MESSAGE
    assert_select "button[aria-pressed='true']", text: "Dinner"
    assert_select "button", text: "Retry"
    assert_select "button", text: "Keep Going by Hand"
    assert_no_match(/Preparing Suggestions/, @response.body)

    post save_and_leave_project_planner_session_path(project, planner_session)
    assert_redirected_to project_path(project)
    assert_equal "asking", planner_session.reload.status
  end

  test "Build it myself starts a Project by hand from the Planner's start" do
    sign_in_as_leader
    get new_project_path
    assert_select "a[href=?]", new_project_path(manual: true), text: "Build It Myself"

    assert_difference "Project.count", 1 do
      post projects_path, params: { project: { name: "Retreat by hand", description: "Built without the Planner.", starts_on: "2027-03-12", ends_on: "2027-03-13" } }
    end
    assert_equal "Retreat by hand", Project.order(:id).last!.name
  end

  private
    def start_and_generate
      perform_enqueued_jobs(only: PlannerStepJob) { post start_meal_planner_projects_path }
      planner_session = PlannerSession.order(:id).last!
      [ planner_session.project, planner_session.reload ]
    end

    def select_and_generate(project, planner_session, answer)
      perform_enqueued_jobs(only: PlannerStepJob) do
        post select_answer_project_planner_session_path(project, planner_session), params: {
          answer:, expected_revision: planner_session.reload.generation_revision
        }
      end
      planner_session.reload.generation_revision
    end

    def use_provider(*responses)
      Planner::Providers::Fake.new(responses).tap do |provider|
        Rails.configuration.x.planner_provider = provider
      end
    end

    def response(card:, finished: false, added: [])
      Planner::Response.new(card:, finished:, added:, removed_ids: [])
    end

    def card(question, *options)
      choices = options.presence || [ "One", "Two", "Three" ]
      choices << "Something else" while choices.size < 3
      { "question" => question, "options" => choices }
    end

    def slot_run(label:, start_date: "2027-02-15")
      {
        "kind" => "slot_run",
        "source_key" => "meal-slots",
        "fields" => {
          "label" => label,
          "start_date" => start_date,
          "end_date" => (Date.iso8601(start_date) + 2).iso8601,
          "time" => "17:30",
          "capacity" => 1
        }
      }
    end

    def undated_slot_run
      {
        "kind" => "slot_run",
        "source_key" => "meal-slots",
        "fields" => {
          "label" => "Bring dinner",
          "start_day_offset" => 0,
          "end_day_offset" => 1,
          "time" => "17:30",
          "capacity" => 1
        }
      }
    end

    def task_suggestion
      {
        "kind" => "task",
        "fields" => { "title" => "Set the table", "details" => "Put out plates." }
      }
    end
end
