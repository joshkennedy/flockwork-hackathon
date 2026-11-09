require "test_helper"
require "timeout"

class PlannerTest < ActionDispatch::IntegrationTest
  class FakeVoiceClientSecretMinter
    attr_reader :calls

    def initialize(secret = "voice-test-secret")
      @secret = secret
      @calls = 0
    end

    def call
      @calls += 1
      @secret
    end
  end

  class RaisingProvider
    attr_reader :contexts

    def initialize
      @contexts = []
    end

    def call(context)
      contexts << context.deep_dup
      raise Timeout::Error, "Planner timed out"
    end
  end

  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_voice_client_secret_minter = Rails.configuration.x.voice_client_secret_minter
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Rails.configuration.x.voice_client_secret_minter = @original_voice_client_secret_minter
  end

  test "a Leader plans Tasks through cards and accepts only kept and edited Suggestions" do
    project = projects(:community_meal)
    fake = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen before guests arrive?",
          "options" => [ "Set the room", "Prepare food", "Welcome volunteers" ]
        }
      ),
      planner_response(
        card: {
          "question" => "What needs a clear owner?",
          "options" => [ "Room setup", "Kitchen prep", "Guest welcome" ]
        },
        added: [ task_suggestion("Set up tables", "Arrange the dining room.", due_in_days: -1) ]
      ),
      planner_response(
        finished: true,
        added: [
          task_suggestion("Prepare welcome table", "Set out name tags."),
          task_suggestion("Print decorative menus", "Use the color printer.")
        ]
      )
    ])
    Rails.configuration.x.planner_provider = fake
    sign_in_as_leader

    get new_project_planner_session_path(project)
    assert_response :success

    assert_difference "PlannerSession.count", 1 do
      post project_planner_sessions_path(project), params: {
        planner_session: { description: "Plan the final week before our neighborhood meal." }
      }
    end

    session = project.planner_sessions.order(:id).last!
    assert_redirected_to project_planner_session_path(project, session)

    follow_redirect!
    assert_select "h1", text: "What should happen before guests arrive?"

    perform_enqueued_jobs do
      post answer_project_planner_session_path(project, session), params: { answer: "Set the room" }
    end
    assert_redirected_to project_planner_session_path(project, session)
    assert_equal [
      {
        question: "What should happen before guests arrive?",
        answer: "Set the room"
      }
    ], fake.contexts.second.fetch(:answers)

    follow_redirect!
    assert_select "h1", text: "What needs a clear owner?"

    perform_enqueued_jobs do
      post answer_project_planner_session_path(project, session), params: {
        answer: "Ask two volunteers to lead setup."
      }
    end
    assert_redirected_to project_planner_session_path(project, session)
    get project_planner_session_path(project, session)
    assert_redirected_to review_project_planner_session_path(project, session)

    suggestions_by_title = session.reload.suggestions.index_by { |suggestion| suggestion.dig("fields", "title") }
    setup_id = suggestions_by_title.fetch("Set up tables").fetch("id")
    welcome_id = suggestions_by_title.fetch("Prepare welcome table").fetch("id")
    dropped_id = suggestions_by_title.fetch("Print decorative menus").fetch("id")
    assert_equal setup_id, fake.contexts.third.fetch(:current_suggestions).sole.fetch(:id)

    patch suggestion_project_planner_session_path(project, session), params: {
      suggestion: { id: setup_id, decision: "keep" }
    }
    patch suggestion_project_planner_session_path(project, session), params: {
      suggestion: {
        id: welcome_id,
        decision: "edit",
        title: "Build the welcome station",
        details: "Put out name tags and markers."
      }
    }
    patch suggestion_project_planner_session_path(project, session), params: {
      suggestion: { id: dropped_id, decision: "drop" }
    }

    assert_difference "project.tasks.count", 2 do
      post accept_project_planner_session_path(project, session), params: { mode: "kept" }
    end

    assert_redirected_to project_path(project)
    assert_equal [ "Build the welcome station", "Set up tables" ], project.tasks.order(:title).pluck(:title)
    assert_nil project.tasks.find_by!(title: "Build the welcome station").assignee
    assert_equal Date.new(2027, 2, 11), project.tasks.find_by!(title: "Set up tables").due_on
    assert_not project.tasks.exists?(title: "Print decorative menus")
    assert_predicate session.reload, :accepted?
  end

  test "a Leader keeps and drops Suggestions from the card page without leaving it" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "Which details should the plan include?",
          "options" => [ "Room setup", "Kitchen prep", "Guest welcome" ]
        },
        added: [
          task_suggestion("Keep tables ready", "Set every table before guests arrive."),
          task_suggestion("Drop paper menus", "Print one menu for every place setting.")
        ]
      )
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Plan the final room setup." }
    }
    planner_session = project.planner_sessions.last!
    suggestions = planner_session.suggestions.index_by { |suggestion| suggestion.dig("fields", "title") }
    kept_id = suggestions.fetch("Keep tables ready").fetch("id")
    dropped_id = suggestions.fetch("Drop paper menus").fetch("id")
    frame_id = ActionView::RecordIdentifier.dom_id(planner_session, :summary)
    turbo_headers = {
      "Accept" => "text/vnd.turbo-stream.html",
      "Turbo-Frame" => frame_id
    }

    patch suggestion_project_planner_session_path(project, planner_session),
      params: { suggestion: { id: kept_id, decision: "keep" } },
      headers: turbo_headers

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal "kept", planner_session.reload.suggestions.find { |item| item.fetch("id") == kept_id }.fetch("status")
    assert_select "turbo-stream[action='replace'][target='#{frame_id}']"
    assert_includes response.body, "Keep tables ready"

    patch suggestion_project_planner_session_path(project, planner_session),
      params: { suggestion: { id: dropped_id, decision: "drop" } },
      headers: turbo_headers

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal "dropped", planner_session.reload.suggestions.find { |item| item.fetch("id") == dropped_id }.fetch("status")
    assert_not_includes response.body, "Drop paper menus"
  end

  test "Planner contexts exclude People, Team, Recipients, and Messages" do
    project = projects(:community_meal)
    organization = project.organization
    team_person = organization.people.create!(
      name: "Zebulon Privacy Sentinel",
      email: "zebulon.sentinel@example.test",
      phone: "+1-555-810-1818"
    )
    recipient_person = organization.people.create!(
      name: "Xanthe Recipient Marker",
      email: "xanthe.marker@example.test",
      phone: "+1-555-810-1919"
    )
    project.memberships.create!(person: team_person, role: :volunteer)
    project.recipients.create!(person: recipient_person)
    project.messages.create!(author: team_person, body: "A private message from Zebulon Privacy Sentinel.")

    fake = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What work comes first?",
          "options" => [ "Setup", "Food", "Welcome" ]
        }
      )
    ])
    Rails.configuration.x.planner_provider = fake
    sign_in_as_leader

    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Plan the room setup and meal service." }
    }

    assert_redirected_to project_planner_session_path(project, project.planner_sessions.last!)
    assert_equal %i[
      project_name
      project_description
      leader_description
      answers
      enabled_tools
      existing_task_titles
      existing_schedule_item_titles
      existing_slot_labels
      existing_booking_descriptions
      existing_purchase_descriptions
      existing_list_names
      existing_skills_needed
      skill_vocabulary
      past_projects
      current_suggestions
    ], fake.contexts.first.keys

    context_json = fake.contexts.to_json
    [ team_person, recipient_person, people(:leader), people(:volunteer) ].each do |person|
      assert_not_includes context_json, person.name
      assert_not_includes context_json, person.email if person.email
      assert_not_includes context_json, person.phone if person.phone
    end
  end

  test "a provider timeout keeps the answer and lets the Leader leave or review" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should volunteers prepare?",
          "options" => [ "Tables", "Food", "Welcome signs" ]
        },
        added: [
          task_suggestion(
            "Set up tables",
            "Arrange twelve tables."
          )
        ]
      )
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Prepare the neighborhood meal." }
    }
    planner_session = project.planner_sessions.last!
    Rails.configuration.x.planner_provider = RaisingProvider.new

    assert_no_difference "project.tasks.count" do
      perform_enqueued_jobs do
        post answer_project_planner_session_path(project, planner_session), params: { answer: "Tables" }
      end
    end

    assert_redirected_to project_planner_session_path(project, planner_session)
    follow_redirect!
    assert_select "[role='alert']", text: PlannerSession::ERROR_MESSAGE
    assert_select "a", text: "Skip to Review"
    assert_select "a", text: "Leave Planner"
    assert_equal [
      {
        "question" => "What should volunteers prepare?",
        "options" => [ "Tables", "Food", "Welcome signs" ],
        "answer" => "Tables"
      }
    ], planner_session.reload.steps
    assert_equal "Planner timed out", planner_session.last_error
    assert_equal "Set up tables", planner_session.suggestions.first.dig("fields", "title")

    post skip_to_review_project_planner_session_path(project, planner_session)
    assert_redirected_to review_project_planner_session_path(project, planner_session)
  end

  test "answering shows Thinking while the Planner step job is queued" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen first?",
          "options" => [ "Set up", "Cook", "Welcome" ]
        }
      ),
      planner_response(
        card: {
          "question" => "What should happen next?",
          "options" => [ "Clean", "Serve", "Close" ]
        },
        added: [
          task_suggestion(
            "Set up the room",
            "Arrange the tables."
          )
        ]
      )
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Prepare the neighborhood meal." }
    }
    planner_session = project.planner_sessions.last!

    assert_enqueued_with(job: PlannerStepJob) do
      post answer_project_planner_session_path(project, planner_session), params: { answer: "Set up" }
    end
    assert_redirected_to project_planner_session_path(project, planner_session)
    follow_redirect!
    assert_select "h1", text: "Thinking…"
    assert_select "p", text: /Suggestions will appear here/

    perform_enqueued_jobs
    assert_equal "What should happen next?", planner_session.reload.current_card.fetch("question")
    assert_equal "Set up the room", planner_session.suggestions.first.dig("fields", "title")
  end

  test "planner surfaces qualified privacy and xAI disclosure before voice start" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "How should the Team prepare?",
          "options" => [ "Cook together", "Order food" ]
        }
      )
    ])
    sign_in_as_leader

    get new_project_planner_session_path(project)
    assert_response :success
    assert_select ".privacy-line", text: /It never sees your people./
    assert_select ".privacy-line", text: /Voice sends your audio to xAI/

    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Prepare the neighborhood meal." }
    }
    planner_session = project.planner_sessions.last!
    get project_planner_session_path(project, planner_session)
    assert_response :success
    assert_includes response.body, "Voice sends your audio to xAI"
    assert_includes response.body, "Talk It Through"
    assert_operator response.body.index("Voice sends your audio to xAI"), :<, response.body.index("Talk It Through")
  end

  test "a Leader mints a voice session from safe Planner context and the current card" do
    project = projects(:community_meal)
    project.organization.people.create!(
      name: "Xavier Voice Sentinel",
      email: "xavier.voice@example.test",
      phone: "+1-555-700-2800"
    )
    question = "How should the Team prepare the meal?"
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => question,
          "options" => [ "Cook together", "Order food", "Ask for donations" ]
        }
      )
    ])
    minter = FakeVoiceClientSecretMinter.new
    Rails.configuration.x.voice_client_secret_minter = minter
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Prepare the neighborhood meal." }
    }
    planner_session = project.planner_sessions.last!

    post voice_session_project_planner_session_path(project, planner_session), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal "voice-test-secret", payload.fetch("client_secret")
    assert_equal "grok-voice-latest", payload.fetch("model")
    assert_equal 1, minter.calls
    assert_includes payload.fetch("instructions"), question
    assert_includes payload.fetch("instructions"), "Cook together"
    assert_includes payload.fetch("instructions"), "Never ask for or repeat people's names"
    assert_equal "answer_card", payload.fetch("tools").sole.fetch("name")
    project.organization.people.find_each do |person|
      [ person.name, person.email, person.phone ].compact.each do |private_value|
        assert_not_includes payload.fetch("instructions"), private_value
      end
    end
  end

  test "a Volunteer cannot mint a voice session" do
    project = projects(:community_meal)
    planner_session = project.planner_sessions.create!(
      started_by: people(:leader),
      description: "Prepare the neighborhood meal.",
      current_card: {
        "question" => "What should happen first?",
        "options" => [ "Cook", "Set up", "Welcome" ]
      }
    )
    Rails.configuration.x.voice_client_secret_minter = FakeVoiceClientSecretMinter.new
    sign_in_as_volunteer

    post voice_session_project_planner_session_path(project, planner_session), as: :json

    assert_response :not_found
  end

  test "typed and voice answers store directory names redacted" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen first?",
          "options" => [ "Cook", "Set up", "Welcome" ]
        }
      ),
      planner_response(
        card: {
          "question" => "What should happen next?",
          "options" => [ "Serve", "Clean", "Close" ]
        }
      )
    ])
    sign_in_as_leader

    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Prepare the neighborhood meal." }
    }
    typed_session = project.planner_sessions.last!
    post answer_project_planner_session_path(project, typed_session), params: {
      answer: "Leo Leader will cook."
    }

    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Finish the neighborhood meal." }
    }
    voice_session = project.planner_sessions.last!
    post answer_project_planner_session_path(project, voice_session), params: {
      answer: "Ask LEO to clean.", source: "voice"
    }

    assert_equal "[name] will cook.", typed_session.reload.steps.sole.fetch("answer")
    assert_equal "Ask [name] to clean.", voice_session.reload.steps.sole.fetch("answer")
  end

  test "a Volunteer cannot start the Planner" do
    project = projects(:community_meal)
    sign_in_as_volunteer

    get project_path(project)
    assert_response :success
    assert_select "a", text: "Plan with AI", count: 0

    get new_project_planner_session_path(project)
    assert_response :not_found

    assert_no_difference "PlannerSession.count" do
      post project_planner_sessions_path(project), params: {
        planner_session: { description: "A Volunteer should not start this." }
      }
    end
    assert_response :not_found
  end

  test "Accept all treats proposed Suggestions as kept" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        finished: true,
        added: [
          task_suggestion(
            "Confirm the serving plan",
            "Review the order of service with the Team."
          )
        ]
      )
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Finish the serving plan." }
    }
    planner_session = project.planner_sessions.last!

    assert_redirected_to review_project_planner_session_path(project, planner_session)
    assert_difference "project.tasks.count", 1 do
      post accept_project_planner_session_path(project, planner_session), params: { mode: "all" }
    end

    assert_redirected_to project_path(project)
    assert_equal "Confirm the serving plan", project.tasks.last!.title
    assert_equal "kept", planner_session.reload.suggestions.first.fetch("status")
  end

  test "accept rejects a multi-skill name" do
    assert_ask_accept_rejected(suggestion("skill", "name" => "Cooking, Driving, Welding"), /Skill is invalid/) do |project|
      -> { project.skills_needed.size }
    end
  end

  test "accept rejects an unknown list column type" do
    list = suggestion("list", "name" => "Stations", "columns" => [ { "name" => "Station", "type" => "bogus" } ])
    assert_ask_accept_rejected(list, /Columns are invalid/) { |project| -> { project.lists.count } }
  end

  test "an enable_tool Suggestion with an unknown tool is dropped and review still renders" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(finished: true, added: [
        suggestion("enable_tool", "tool" => "bogus"),
        task_suggestion("Confirm the serving plan", "Review the order of service.")
      ])
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: { planner_session: { description: "Plan the meal." } }
    planner_session = project.planner_sessions.last!

    assert_equal [ "task" ], planner_session.suggestions.pluck("kind")
    get review_project_planner_session_path(project, planner_session)
    assert_response :success
  end

  test "review shows each Suggestion's parameters" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(finished: true, added: [
        task_suggestion("Confirm the serving plan", "Review the order of service.", due_in_days: 3),
        suggestion("list", "name" => "Stations", "columns" => [ { "name" => "Station", "type" => "text" } ])
      ])
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: { planner_session: { description: "Plan the meal." } }

    get review_project_planner_session_path(project, project.planner_sessions.last!)

    assert_select ".suggestion-params", text: /Due in days: 3/
    assert_select ".suggestion-params", text: /Details: Review the order of service\./
    assert_select ".suggestion-params", text: /Columns: Station \(text\)/
  end

  test "accept creates every Suggestion kind with literal values and enables matching Tools" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        finished: true,
        added: [
          suggestion("enable_tool", "tool" => "docs"),
          suggestion(
            "task",
            "title" => "Confirm table captains",
            "details" => "Write the final setup assignments.",
            "due_in_days" => 2,
            "role" => "1 setup lead"
          ),
          suggestion(
            "schedule_item",
            "title" => "Volunteer briefing",
            "day_offset" => 1,
            "starts_at" => "09:15",
            "ends_at" => "10:00",
            "location" => "Fellowship Hall"
          ),
          suggestion(
            "slot_run",
            "label" => "Dinner delivery",
            "start_day_offset" => 1,
            "end_day_offset" => 3,
            "time" => "17:30",
            "capacity" => 2
          ),
          suggestion(
            "booking",
            "description" => "Community room",
            "estimated_dollars" => 425.50,
            "role" => "1 booking lead"
          ),
          suggestion(
            "purchase",
            "description" => "Compostable plates",
            "estimated_dollars" => 86.25,
            "role" => "1 purchasing lead"
          ),
          suggestion(
            "list",
            "name" => "Serving stations",
            "columns" => [
              { "name" => "Station", "type" => "text" },
              { "name" => "Ready", "type" => "checkbox" }
            ]
          )
        ]
      )
    ])
    sign_in_as_leader

    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Add the final operating details." }
    }
    planner_session = project.planner_sessions.last!

    assert_difference -> { project.tasks.count }, 1 do
      assert_difference -> { project.schedule_items.count }, 1 do
        assert_difference -> { project.slots.count }, 3 do
          assert_difference -> { project.budget_lines.count }, 2 do
            assert_difference -> { project.lists.count }, 1 do
              post accept_project_planner_session_path(project, planner_session), params: { mode: "all" }
            end
          end
        end
      end
    end

    assert_redirected_to project_path(project)
    assert_equal %w[budget docs list messages schedule signup_sheet tasks], project.reload.enabled_tools.sort

    task = project.tasks.find_by!(title: "Confirm table captains")
    assert_equal "Write the final setup assignments.", task.details.to_plain_text
    assert_equal Date.new(2027, 2, 14), task.due_on
    assert_nil task.assignee

    schedule_item = project.schedule_items.find_by!(title: "Volunteer briefing")
    assert_equal Date.new(2027, 2, 13), schedule_item.date
    assert_equal "09:15", schedule_item.starts_at_time.strftime("%H:%M")
    assert_equal "10:00", schedule_item.ends_at_time.strftime("%H:%M")
    assert_equal "Fellowship Hall", schedule_item.location

    slots = project.slots.where(label: "Dinner delivery").chronological
    assert_equal [ Date.new(2027, 2, 13), Date.new(2027, 2, 14), Date.new(2027, 2, 15) ], slots.pluck(:date)
    assert_equal [ "17:30", "17:30", "17:30" ], slots.map { |slot| slot.starts_at_time.strftime("%H:%M") }
    assert_equal [ 2, 2, 2 ], slots.pluck(:capacity)

    booking = project.budget_lines.booking.find_by!(description: "Community room")
    purchase = project.budget_lines.purchase.find_by!(description: "Compostable plates")
    assert_equal 42_550, booking.estimated_cents
    assert_equal 8_625, purchase.estimated_cents
    assert_nil booking.responsible_person
    assert_nil purchase.responsible_person

    list = project.lists.find_by!(name: "Serving stations")
    assert_equal [ [ "Station", "text" ], [ "Ready", "checkbox" ] ],
      list.columns.map { |column| [ column.name, column.column_type ] }
  end

  test "Plan more context includes existing item titles and enabled Tools" do
    project = projects(:building_cleanup)
    project.update!(enabled_tools: %w[tasks schedule signup_sheet budget list])
    project.tasks.create!(title: "Patch hallway wall")
    project.schedule_items.create!(title: "Morning walkthrough", date: Date.new(2027, 3, 20))
    project.slots.create!(label: "Paint crew", date: Date.new(2027, 3, 20), capacity: 3)
    project.budget_lines.create!(kind: :booking, description: "Floor buffer", estimated: "175.00")
    project.budget_lines.create!(kind: :purchase, description: "Painter tape", estimated: "42.75")
    project.lists.create!(name: "Room checklist")
    fake = Planner::Providers::Fake.new([
      planner_response(finished: true)
    ])
    Rails.configuration.x.planner_provider = fake
    sign_in_as(:other_leader)

    get project_path(project)
    assert_select "a", text: "Plan More"
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Add the final cleanup assignments." }
    }

    context = fake.contexts.first
    assert_equal %w[tasks schedule signup_sheet budget list], context.fetch(:enabled_tools)
    assert_equal [ "Patch hallway wall" ], context.fetch(:existing_task_titles)
    assert_equal [ "Morning walkthrough" ], context.fetch(:existing_schedule_item_titles)
    assert_equal [ "Paint crew" ], context.fetch(:existing_slot_labels)
    assert_equal [ "Floor buffer" ], context.fetch(:existing_booking_descriptions)
    assert_equal [ "Painter tape" ], context.fetch(:existing_purchase_descriptions)
    assert_equal [ "Room checklist" ], context.fetch(:existing_list_names)
  end

  test "review edits nested List fields before accepting" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        finished: true,
        added: [
          suggestion(
            "list",
            "name" => "Serving stations",
            "columns" => [ { "name" => "Station", "type" => "text" } ]
          )
        ]
      )
    ])
    sign_in_as_leader
    post project_planner_sessions_path(project), params: {
      planner_session: { description: "Create a serving station List." }
    }
    planner_session = project.planner_sessions.last!
    suggestion_id = planner_session.suggestions.sole.fetch("id")

    get review_project_planner_session_path(project, planner_session)
    assert_response :success
    assert_select "input[name='suggestion[fields][name]'][value='Serving stations']"
    assert_select "input[name='suggestion[fields][columns][0][name]'][value='Station']"
    assert_select "select[name='suggestion[fields][columns][0][type]'] option[selected]", text: "Text"

    patch suggestion_project_planner_session_path(project, planner_session), params: {
      suggestion: {
        id: suggestion_id,
        decision: "edit",
        fields: {
          name: "Meal teams",
          columns: [
            { name: "Team name", type: "text" },
            { name: "Confirmed", type: "checkbox" }
          ]
        }
      }
    }
    post accept_project_planner_session_path(project, planner_session), params: { mode: "kept" }

    list = project.lists.find_by!(name: "Meal teams")
    assert_equal [ [ "Team name", "text" ], [ "Confirmed", "checkbox" ] ],
      list.columns.map { |column| [ column.name, column.column_type ] }
  end

  test "past Project context excludes deleted Projects and People" do
    current_project = projects(:community_meal)
    organization = current_project.organization
    private_person = organization.people.create!(
      name: "Past Project Private Person",
      email: "past-private@example.test",
      phone: "+1-555-300-4019"
    )
    past_project = organization.projects.create!(
      name: "Previous Community Supper",
      description: "A prior meal.",
      owner: private_person,
      enabled_tools: %w[tasks budget]
    )
    past_project.memberships.create!(person: private_person, role: :leader)
    past_project.memberships.create!(person: people(:leader), role: :leader)
    past_project.tasks.create!(title: "Arrange old tables")
    past_project.budget_lines.create!(kind: :booking, description: "Old hall", estimated: "300")
    past_project.budget_lines.create!(kind: :purchase, description: "Old napkins", estimated: "45")
    deleted_project = organization.projects.create!(
      name: "Deleted Private Project",
      owner: private_person,
      enabled_tools: [ "tasks" ],
      deleted_at: Time.current
    )
    deleted_project.tasks.create!(title: "Deleted sentinel task")
    fake = Planner::Providers::Fake.new([
      planner_response(finished: true)
    ])
    Rails.configuration.x.planner_provider = fake
    sign_in_as_leader

    post project_planner_sessions_path(current_project), params: {
      planner_session: { description: "Use the useful shape of earlier meals." }
    }

    previous = fake.contexts.first.fetch(:past_projects).find do |project_context|
      project_context.fetch(:task_titles) == [ "Arrange old tables" ]
    end
    assert_equal %w[tasks budget], previous.fetch(:tool_mix)
    assert_equal 1, previous.fetch(:task_count)
    assert_equal [ "Arrange old tables" ], previous.fetch(:task_titles)
    assert_equal 1, previous.fetch(:booking_count)
    assert_equal [ "Old hall" ], previous.fetch(:booking_descriptions)
    assert_equal 1, previous.fetch(:purchase_count)
    assert_equal [ "Old napkins" ], previous.fetch(:purchase_descriptions)

    context_json = fake.contexts.to_json
    assert_not_includes context_json, "Deleted sentinel task"
    assert_not_includes context_json, private_person.name
    assert_not_includes context_json, private_person.email
    assert_not_includes context_json, private_person.phone
  end

  private
    def assert_ask_accept_rejected(added, message)
      project = projects(:community_meal)
      Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([ planner_response(finished: true, added: [ added ]) ])
      sign_in_as_leader
      post project_planner_sessions_path(project), params: { planner_session: { description: "Plan the meal." } }
      planner_session = project.planner_sessions.last!

      assert_no_difference yield(project) do
        post accept_project_planner_session_path(project, planner_session), params: { mode: "all" }
      end

      assert_redirected_to review_project_planner_session_path(project, planner_session)
      assert_predicate planner_session.reload, :reviewing?
      assert_match message, flash[:alert]
    end

    def planner_response(card: nil, finished: false, added: [], removed_ids: [])
      Planner::Response.new(card:, finished:, added:, removed_ids:)
    end

    def task_suggestion(title, details, due_in_days: nil)
      fields = { "title" => title, "details" => details }
      fields["due_in_days"] = due_in_days unless due_in_days.nil?
      {
        "kind" => "task",
        "fields" => fields
      }
    end

    def suggestion(kind, fields)
      {
        "kind" => kind,
        "fields" => fields
      }
    end
end
