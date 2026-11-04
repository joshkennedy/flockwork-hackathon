require "test_helper"
require_relative "../support/method_stubs"

class MessageDraftsTest < ActionDispatch::IntegrationTest
  include MethodStubs

  test "generating does not save or notify and only explicit posting persists a message" do
    person = sign_in_as_leader
    project = Project.create_for(creator: person, attributes: { name: "Draft review", enabled_tools: [ "messages" ] })
    provider = ->(*) { { "title" => "About {{project}}", "body" => "Please review the Project." } }
    stub_method(ProjectMessageDraft, :provider, -> { provider }) do
      assert_no_difference [ "Message.count", "Notification.count" ] do
        post project_message_draft_path(project), params: { purpose: "announcement" }
        assert_response :success
        assert_select "textarea", text: /About Draft review/
      end
    end
    assert_difference "Message.count", 1 do
      post project_messages_path(project), params: { message: { body: "Edited draft ready to post" } }
      assert_redirected_to project_path(project)
    end
  end

  test "provider error preserves draft type without exposing provider details" do
    sign_in_as_admin
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools | [ "messages", "signup_sheet" ])
    project.slots.create!(label: "Open for draft", date: Date.tomorrow)
    stub_method(ProjectMessageDraft, :provider, -> { ->(*) { raise "secret-key" } }) do
      post project_message_draft_path(project), params: { purpose: "open_spots" }
      assert_response :unprocessable_entity
      assert_select "option[value=open_spots][selected]"
      assert_select "[role=alert]", text: /Drafting is unavailable/
      assert_no_match(/secret-key/, response.body)
    end
  end

  test "volunteers and other churches cannot generate drafts" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools | [ "messages", "signup_sheet" ])
    get new_project_message_draft_path(project)
    assert_response :not_found
    sign_in_as_outsider
    post project_message_draft_path(project), params: { purpose: "announcement" }
    assert_response :not_found
  end

  test "generation rate limit is per person across Projects" do
    sign_in_as_admin
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools | [ "messages", "signup_sheet" ])
    provider = ->(*) { { "title" => "Welcome", "body" => "Review the Project." } }
    store = ActiveSupport::Cache::MemoryStore.new
    stub_method(MessageDraftsController.cache_store, :increment, ->(*args, **kwargs) { store.increment(*args, **kwargs) }) do
      stub_method(ProjectMessageDraft, :provider, -> { provider }) do
        5.times do
          post project_message_draft_path(project), params: { purpose: "announcement" }
          assert_response :success
        end
        another = Project.create_for(creator: people(:admin), attributes: { name: "Another draft Project", enabled_tools: [ "messages" ] })
        post project_message_draft_path(another), params: { purpose: "announcement" }
        assert_response :too_many_requests
        assert_select "[role=alert]", text: /Wait ten minutes/
        sign_in_as(:other_leader)
        post project_message_draft_path(project), params: { purpose: "announcement" }
        assert_response :success
      end
    end
  end
end
