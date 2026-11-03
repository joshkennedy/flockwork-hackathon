require "application_system_test_case"

class PlannerDictationSystemTest < ApplicationSystemTestCase
  NO_SPEECH_RECOGNITION = <<~JS
    delete window.SpeechRecognition
    delete window.webkitSpeechRecognition
  JS

  FAKE_SPEECH_RECOGNITION = <<~JS
    class FakeSpeechRecognition {
      constructor() {
        this.interimResults = false
        this.lang = ""
        this.onresult = null
        this.onend = null
        this.onerror = null
      }

      start() {
        window.setTimeout(() => {
          if (this.onresult) {
            const result = {
              0: { transcript: "two drivers needed" },
              isFinal: true,
              length: 1
            }
            this.onresult({ resultIndex: 0, results: [ result ] })
          }
          if (this.onend) this.onend()
        }, 500)
      }

      stop() {
        if (this.onend) this.onend()
      }
    }
    window.SpeechRecognition = FakeSpeechRecognition
  JS

  setup do
    @project = projects(:community_meal)
  end

  test "dictation button stays hidden when SpeechRecognition is unavailable" do
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.add_init_script(script: NO_SPEECH_RECOGNITION)
    end

    sign_in_leader_in_browser

    visit new_project_planner_session_path(@project)

    assert_selector "button[aria-label='Dictate'][hidden]", visible: :all
  end

  test "dictation fills the planner field and stays editable when SpeechRecognition works" do
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.add_init_script(script: FAKE_SPEECH_RECOGNITION)
    end

    sign_in_leader_in_browser
    visit new_project_planner_session_path(@project)

    find("button[aria-label='Dictate']").click

    assert_selector "button[aria-label='Stop dictating'][aria-pressed='true']"
    assert_text "Listening…"
    assert has_field?("Describe this plan in one sentence", with: "two drivers needed", wait: 5)

    field = find("[data-dictation-target='field']")
    field.set("two drivers needed, edited")
    assert_equal "two drivers needed, edited", field.value
  end

  private
    def sign_in_leader_in_browser
      leader = people(:leader)
      token = leader.generate_token_for(:sign_in)
      visit sign_in_link_path(token)
      click_on "Sign In"
      assert_selector "[data-signed-in-as]", text: "Leo Leader"
    end
end
