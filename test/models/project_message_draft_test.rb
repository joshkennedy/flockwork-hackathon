require "test_helper"
require_relative "../support/method_stubs"

class ProjectMessageDraftTest < ActiveSupport::TestCase
  include MethodStubs
  test "provider sees only safe counts and dates with project name substituted locally" do
    project = projects(:community_meal)
    project.name = "#{people(:volunteer).name} private Project"
    project.description = "Do not send care details or volunteer@example.test"
    payload = nil
    provider = ->(facts) { payload = facts; { "title" => "About {{project}}", "body" => "Please review {{project}} and choose a spot." } }
    draft = nil
    assert_no_difference [ "Message.count", "Notification.count" ] do
      draft = ProjectMessageDraft.new(project, provider: provider).call("announcement")
    end
    assert_equal "About #{project.name}", draft.title
    assert_equal "{{project}}", payload.fetch("project_name")
    assert_no_match(/private|care details|volunteer@example|#{Regexp.escape(people(:volunteer).name)}/, payload.to_json)
  end

  test "provider never sees Slot claim notes" do
    project = projects(:community_meal)
    sentinel = "PRIVATE-POTLUCK-NOTE-8426"
    slot = project.slots.create!(date: Date.tomorrow, label: "Desserts", capacity: 4, claim_prompt: "What are you bringing?")
    slot.claim(people(:volunteer), note: sentinel)
    payload = nil
    provider = ->(facts) { payload = facts; { "title" => "About {{project}}", "body" => "Please review {{project}}." } }

    ProjectMessageDraft.new(project, provider:).call("announcement")

    assert_not_nil payload
    assert_not_includes payload.to_json, sentinel
  end

  test "provider failures and invented numbers produce readable errors" do
    provider = ->(*) { raise "SECRET provider credentials" }
    error = assert_raises(ProjectMessageDraft::Unavailable) { ProjectMessageDraft.new(projects(:community_meal), provider: provider).call("announcement") }
    assert_no_match(/SECRET|credentials/, error.message)
    invalid = ->(*) { { "title" => "Welcome", "body" => "We need 987654 volunteers." } }
    assert_raises(ProjectMessageDraft::Unavailable) { ProjectMessageDraft.new(projects(:community_meal), provider: invalid).call("announcement") }
  end

  test "unrecognized requests never reach provider" do
    provider = ->(*) { flunk "invalid request reached provider" }
    assert_raises(ProjectMessageDraft::Unavailable) { ProjectMessageDraft.new(projects(:community_meal), provider: provider).call("private instructions") }
  end

  test "human-readable dates allow the same numeric day in a generated draft" do
    project = projects(:community_meal)
    project.starts_on = Date.new(2026, 11, 4)
    project.ends_on = Date.new(2026, 11, 5)
    payload = nil
    provider = ->(facts) { payload = facts; { "title" => "Join {{project}}", "body" => "Please join us November 4, 2026." } }
    draft = ProjectMessageDraft.new(project, provider: provider).call("announcement")
    assert_equal "November 4, 2026", payload.fetch("starts_on")
    assert_includes draft.body, "November 4, 2026"
  end

  test "open-spots requests with no upcoming vacancies never reach provider" do
    project = Project.create_for(creator: people(:admin), attributes: { name: "No vacancies", enabled_tools: [ "signup_sheet", "messages" ] })
    provider = ->(*) { flunk "no vacancies should not call provider" }
    error = assert_raises(ProjectMessageDraft::Unavailable) { ProjectMessageDraft.new(project, provider: provider).call("open_spots") }
    assert_includes error.message, "Choose an announcement"
    project.update!(done_at: Time.current)
    assert_raises(ProjectMessageDraft::Unavailable) { ProjectMessageDraft.new(project, provider: provider).call("open_spots") }
  end


  test "draft-specific provider configuration and fenced JSON replies work together" do
    keys = %w[MESSAGE_DRAFT_LLM_PROVIDER MESSAGE_DRAFT_LLM_MODEL MESSAGE_DRAFT_LLM_BUDGET_SECONDS ANTHROPIC_API_KEY]
    previous = ENV.to_h.slice(*keys)
    ENV["MESSAGE_DRAFT_LLM_PROVIDER"] = "anthropic"
    ENV["MESSAGE_DRAFT_LLM_MODEL"] = "configured-model"
    ENV["MESSAGE_DRAFT_LLM_BUDGET_SECONDS"] = "0.5"
    ENV["ANTHROPIC_API_KEY"] = "test-only"
    config = Struct.new(:request_timeout).new
    selected = nil
    chat = Object.new
    chat.define_singleton_method(:chat) { |**options| selected = options; self }
    chat.define_singleton_method(:with_instructions) { |*| self }
    chat.define_singleton_method(:with_max_output_tokens) { |*| self }
    chat.define_singleton_method(:ask) { |*| Struct.new(:content).new(%(```json\n{"title":"Welcome","body":"Please review the Project."}\n```)) }
    stub_method(RubyLLM, :context, ->(&configure) { configure.call(config); chat }) do
      result = ProjectMessageDraft::Llm.new.call({})
      assert_equal "Welcome", result.fetch("title")
    end
    assert_equal :anthropic, selected.fetch(:provider)
    assert_equal "configured-model", selected.fetch(:model)
    assert_equal 0.5, config.request_timeout
  ensure
    keys.each { |key| previous.key?(key) ? ENV[key] = previous.fetch(key) : ENV.delete(key) }
  end
end
