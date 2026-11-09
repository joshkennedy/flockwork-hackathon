require "test_helper"

class PlannerContextBuilderTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "ask-mode context and voice instructions redact directory full names" do
    organization = organizations(:st_example)
    leader = people(:leader)
    directory_name = people(:volunteer).name
    project = organization.projects.create!(
      name: "Plan with #{directory_name}",
      description: "Ask #{directory_name} to coordinate.",
      owner: leader,
      enabled_tools: [ "tasks" ]
    )
    project.memberships.create!(person: leader, role: :leader)
    planner_session = project.planner_sessions.create!(
      started_by: leader,
      description: "Have #{directory_name} lead the work.",
      flow_version: 1,
      current_card: {
        "question" => "Should #{directory_name} coordinate?",
        "options" => [ "Yes", "Ask #{directory_name} later" ]
      }
    )
    fake = Planner::Providers::Fake.new([
      Planner::Response.new(
        card: { "question" => "What should happen next?", "options" => [ "Prepare" ] },
        finished: false,
        added: [],
        removed_ids: []
      )
    ])
    Rails.configuration.x.planner_provider = fake
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    Current.set(session: current_session) do
      builder = Planner::ContextBuilder.new(planner_session)
      builder.ask

      assert_not_includes fake.contexts.to_json, directory_name
      assert_not_includes builder.voice_instructions, directory_name
    end
  end

  test "build-as-you-go context redacts directory names before JSON encoding" do
    organization = organizations(:st_example)
    leader = people(:leader)
    directory_name = "Ann \"Annie\" Lee"
    organization.people.create!(name: directory_name)
    project = organization.projects.create!(
      name: "Quoted name project",
      description: "Plan the work.",
      owner: leader,
      enabled_tools: [ "tasks" ]
    )
    project.memberships.create!(person: leader, role: :leader)
    planner_session = project.planner_sessions.create!(
      started_by: leader,
      description: "Ask #{directory_name} to coordinate.",
      flow_version: 3
    )
    fake = Planner::Providers::Fake.new([
      Planner::Response.new(
        card: nil,
        finished: false,
        added: [],
        removed_ids: []
      )
    ])
    Rails.configuration.x.planner_provider = fake
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    Current.set(session: current_session) do
      Planner::ContextBuilder.new(planner_session).ask
    end

    assert_equal "Ask [name] to coordinate.", fake.contexts.first.fetch("project_intent")
  end

  test "voice instructions distinguish a waiting builder from review" do
    leader = people(:leader)
    project = projects(:community_meal)
    waiting = project.planner_sessions.create!(
      started_by: leader,
      description: "Plan a workday.",
      flow_version: 3,
      planning_kind: "workday"
    )
    reviewing = project.planner_sessions.create!(
      started_by: leader,
      description: "Plan a workday.",
      flow_version: 3,
      planning_kind: "workday",
      status: :reviewing
    )
    current_session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    Current.set(session: current_session) do
      waiting_instructions = Planner::ContextBuilder.new(waiting).voice_instructions
      reviewing_instructions = Planner::ContextBuilder.new(reviewing).voice_instructions

      assert_includes waiting_instructions, "The first question is being prepared"
      assert_not_includes waiting_instructions, "The plan is ready for review"
      assert_includes reviewing_instructions, "The plan is ready for review"
    end
  end

  test "randomized Planner contexts never contain generated Person data" do
    random = Random.new(18)
    organization = organizations(:st_example)
    responses = Array.new(30) do
      Planner::Response.new(
        card: {
          "question" => "What should happen next?",
          "options" => [ "Prepare", "Coordinate", "Review" ]
        },
        finished: false,
        added: [],
        removed_ids: []
      )
    end
    fake = Planner::Providers::Fake.new(responses)
    Rails.configuration.x.planner_provider = fake
    generated_people = []
    current_session = people(:leader).sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    Current.set(session: current_session) do
      30.times do |iteration|
        team = Array.new(random.rand(1..4)) do |person_index|
          token = random.rand(100_000..999_999)
          organization.people.create!(
            name: "Zebulon Qx#{iteration}#{person_index} #{token}",
            email: "zebulon-qx#{iteration}-#{person_index}-#{token}@example.test",
            phone: "+1-555-#{iteration.to_s.rjust(2, "0")}-#{token}"
          ).tap { |person| generated_people << person }
        end
        project = organization.projects.create!(
          name: "Random Project #{iteration}",
          description: "A generated planning scenario #{random.rand(1_000_000)}.",
          owner: team.first,
          enabled_tools: [ "tasks" ]
        )
        team.each_with_index do |person, index|
          project.memberships.create!(person:, role: index.zero? ? :leader : :volunteer)
        end
        random.rand(1..5).times do |task_index|
          project.tasks.create!(title: "Generated Task #{iteration}-#{task_index}-#{random.rand(1_000_000)}")
        end
        planner_session = project.planner_sessions.create!(
          started_by: team.first,
          description: "Build the work plan for randomized Project #{iteration}."
        )

        Planner::ContextBuilder.new(planner_session).ask
      end
    end

    assert_equal 30, fake.contexts.length
    fake.contexts.each do |context|
      assert_operator context.fetch(:past_projects).length, :<=, 5
    end

    context_json = fake.contexts.to_json
    generated_people.each do |person|
      assert_not_includes context_json, person.name
      assert_not_includes context_json, person.email
      assert_not_includes context_json, person.phone
    end
  end

  test "the legacy Planner sees skills_needed and the vocabulary, never People's skills, and a kept skill is saved" do
    people(:volunteer).update!(skills: [ "zzz-sentinel-skill" ])
    project = projects(:community_meal)
    project.update!(skills_needed: [ "cooking" ])
    fake = Planner::Providers::Fake.new([
      Planner::Response.new(card: { "question" => "Who cooks?", "options" => %w[A B C] }, finished: false, added: [], removed_ids: [])
    ])
    Rails.configuration.x.planner_provider = fake
    planner_session = project.planner_sessions.create!(started_by: people(:leader), description: "Plan the meal.")
    Current.set(session: people(:leader).sessions.create!(ip_address: "127.0.0.1", user_agent: "test")) do
      Planner::ContextBuilder.new(planner_session).ask
    end

    context = fake.contexts.first
    assert_equal [ "cooking" ], context.fetch(:existing_skills_needed)
    assert_includes context.fetch(:skill_vocabulary), "Driving"
    assert_not_includes context.to_json, "zzz-sentinel-skill"

    tools = project.enabled_tools.dup
    Planner::SuggestionKinds.create!(project, { "kind" => "skill", "fields" => { "name" => "Driving" } })
    assert_equal %w[cooking driving], project.reload.skills_needed
    assert_equal tools, project.enabled_tools
  end
end
