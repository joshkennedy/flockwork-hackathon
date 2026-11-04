require "application_system_test_case"
require_relative "../support/method_stubs"

class MessageDraftSystemTest < ApplicationSystemTestCase
  include MethodStubs

  test "a Leader reviews edits and explicitly posts a generated draft" do
    project = Project.create_for(creator: people(:grace_leader), attributes: { name: "Draft browser Project", enabled_tools: [ "messages" ] })
    provider = ->(*) { { "title" => "About {{project}}", "body" => "Please review the Project." } }
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(project)
    click_on "Draft a Message"
    stub_method(ProjectMessageDraft, :provider, -> { provider }) do
      click_on "Generate Draft"
      assert_selector "textarea", text: /About Draft browser Project/
    end
    assert_equal 0, project.messages.count
    find("textarea").set("Human edited this draft before posting.")
    click_on "Post Message"
    assert_selector "#tab-messages", text: "Human edited this draft before posting."
    assert_equal "Human edited this draft before posting.", project.messages.last.body.to_plain_text
  end
end
