require "test_helper"

class PlannerContextBuilderTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Current.reset
  end

  test "randomized Planner contexts never contain generated Person data" do
    random = Random.new(18)
    workspace = workspaces(:st_example)
    responses = Array.new(30) do
      Planner::Response.new(
        card: {
          "question" => "What should happen next?",
          "options" => [ "Prepare", "Coordinate", "Review" ]
        },
        finished: false,
        suggestions: []
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
          workspace.people.create!(
            name: "Zebulon Qx#{iteration}#{person_index} #{token}",
            email: "zebulon-qx#{iteration}-#{person_index}-#{token}@example.test",
            phone: "+1-555-#{iteration.to_s.rjust(2, "0")}-#{token}"
          ).tap { |person| generated_people << person }
        end
        project = workspace.projects.create!(
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
end
