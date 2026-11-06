require "test_helper"

class ProjectDebriefTest < ActiveSupport::TestCase
  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @source = projects(:community_meal)
    @source.update!(done_at: Time.current)
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
  end

  test "answers are optional and each Project has one debrief" do
    debrief = @source.create_project_debrief!(what_worked: nil, change_next_time: "  ")
    assert_equal "", debrief.reload.what_worked
    assert_empty debrief.notes_body
    assert_not ProjectDebrief.new(project: @source).valid?
    assert_raises ActiveRecord::RecordNotUnique do
      ProjectDebrief.insert_all!([ { project_id: @source.id, created_at: Time.current, updated_at: Time.current } ])
    end
  end

  test "duplicating carries answers into a Leader-only note without changing the source" do
    debrief = @source.create_project_debrief!(what_worked: "Small teams", change_next_time: "Start earlier")
    copy = ProjectDuplicate.new(source: @source, start_on: @source.starts_on.next_year, by: people(:other_leader)).call
    note = copy.notes.sole
    assert note.leaders?
    assert_equal people(:other_leader), note.author
    assert_equal copy.organization, note.organization
    assert_includes note.body, "Small teams"
    assert_includes note.body, "Start earlier"
    assert_nil copy.project_debrief
    assert_equal "Small teams", debrief.reload.what_worked
    assert_empty @source.notes

    copy.memberships.create!(person: people(:volunteer), role: :volunteer)
    assert_empty Policy.visible_notes(people(:volunteer), copy.notes)
    assert_equal [ note ], Policy.visible_notes(people(:other_leader), copy.notes).to_a
  end

  test "both Planner flows use only redacted debrief answers from completed same-church Projects" do
    @source.create_project_debrief!(what_worked: "Leo Leader prepared clear roles", change_next_time: "Ask Vic Volunteer earlier")
    @source.notes.create!(organization: @source.organization, author: people(:admin), visibility: :admins, body: "Private pastoral sentinel")
    outsider = projects(:outsider_project)
    outsider.update!(done_at: Time.current)
    outsider.create_project_debrief!(what_worked: "Other church sentinel")
    outsider.tasks.create!(title: "Other church task sentinel")
    outsider.budget_lines.create!(kind: :purchase, description: "Other church budget sentinel", estimated: "20")
    private_project = Project.create_for(creator: people(:admin), attributes: { name: "Private history", done_at: Time.current })
    private_project.create_project_debrief!(what_worked: "Other Leaders private debrief sentinel")
    private_project.tasks.create!(title: "Other Leaders private task sentinel")
    private_project.budget_lines.create!(kind: :purchase, description: "Other Leaders private budget sentinel", estimated: "20")
    @source.tasks.create!(title: "Authorized history task")
    @source.budget_lines.create!(kind: :purchase, description: "Authorized history budget", estimated: "20")
    current = projects(:building_cleanup)

    Current.set(session: Session.new(person: people(:leader))) do
      [ 1, 3 ].each do |version|
        session = current.planner_sessions.new(started_by: people(:leader), description: "Plan setup", flow_version: version)
        response = Planner::Response.new(card: nil, finished: true, added: [], removed_ids: [])
        provider = Planner::Providers::Fake.new([ response, response ])
        Rails.configuration.x.planner_provider = provider
        Planner::ContextBuilder.new(session).ask
        context = provider.contexts.last
        history = context[version == 1 ? :past_projects : "past_projects"]
        json = history.to_json
        assert_includes json, "[name] prepared clear roles"
        assert_includes json, "Ask [name] earlier"
        assert_not_includes json, "Leo Leader"
        assert_not_includes json, "Vic Volunteer"
        assert_not_includes json, "Private pastoral sentinel"
        assert_not_includes json, "Other church sentinel"
        assert_not_includes json, "Other Leaders private debrief sentinel"
        assert_not_includes json, "Other Leaders private task sentinel"
        assert_not_includes json, "Other Leaders private budget sentinel"
        assert_not_includes json, "Other church task sentinel"
        assert_not_includes json, "Other church budget sentinel"
        assert_includes json, "Authorized history task"
        assert_includes json, "Authorized history budget"
      end
      @source.update!(done_at: nil)
      session = current.planner_sessions.new(started_by: people(:leader), description: "Plan setup", flow_version: 1)
      Planner::ContextBuilder.new(session).ask
      history = Rails.configuration.x.planner_provider.contexts.last.fetch(:past_projects)
      assert_not_includes history.to_json, "prepared clear roles"
    end
  end
end
