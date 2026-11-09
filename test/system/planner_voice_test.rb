require "application_system_test_case"

class PlannerVoiceSystemTest < ApplicationSystemTestCase
  FAKE_VOICE_BROWSER = <<~JS
    window.__voiceEvents = []
    window.__voiceScripts = []
    window.__voiceSessionUpdates = 0
    window.__voiceRespondedUpdates = []
    window.__NativeWebSocket = window.WebSocket

    class FakeWebSocket {
      static OPEN = 1
      static CLOSED = 3

      constructor(url, protocols) {
        if (!url.startsWith("wss://api.x.ai")) return new window.__NativeWebSocket(url, protocols)

        this.url = url
        this.protocols = protocols
        this.readyState = 0
        window.setTimeout(() => {
          this.readyState = FakeWebSocket.OPEN
          if (this.onopen) this.onopen()
        }, 0)
      }

      send(payload) {
        const event = JSON.parse(payload)
        window.__voiceEvents.push(event)
        if (event.type === "session.update") {
          window.__voiceSessionUpdates += 1
          return
        }
        if (event.type !== "response.create") return

        const update = window.__voiceSessionUpdates
        const script = window.__voiceScripts[update - 1]
        const answered = window.__voiceRespondedUpdates.includes(update)
        const playScript = script && !answered
        if (playScript) window.__voiceRespondedUpdates.push(update)
        window.setTimeout(() => {
          if (!playScript) {
            this.onmessage({ data: JSON.stringify({
              type: "response.output_audio_transcript.delta",
              delta: "Got it, adding that to your plan."
            }) })
            this.onmessage({ data: JSON.stringify({ type: "response.done" }) })
            return
          }
          this.onmessage({ data: JSON.stringify({
            type: "response.output_audio_transcript.delta",
            delta: script.question
          }) })
          this.onmessage({ data: JSON.stringify({
            type: "conversation.item.input_audio_transcription.completed",
            transcript: script.answer
          }) })
          this.onmessage({ data: JSON.stringify({
            type: "response.function_call_arguments.done",
            name: "answer_card",
            call_id: `voice-call-${update}`,
            arguments: JSON.stringify({ answer: script.answer })
          }) })
          this.onmessage({ data: JSON.stringify({ type: "response.done" }) })
        }, 25)
      }

      close() {
        this.readyState = FakeWebSocket.CLOSED
        if (this.onclose) this.onclose({ code: 1000 })
      }
    }

    class FakeAudioContext {
      constructor() {
        this.sampleRate = 24000
        this.currentTime = 0
        this.destination = {}
      }

      createMediaStreamSource() { return { connect() {}, disconnect() {} } }
      createScriptProcessor() { return { connect() {}, disconnect() {}, onaudioprocess: null } }
      close() { return Promise.resolve() }
    }

    window.WebSocket = FakeWebSocket
    window.AudioContext = FakeAudioContext
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: async () => ({ getTracks: () => [ { stop() {} } ] })
      }
    })
  JS

  class FakeVoiceClientSecretMinter
    def call = "system-voice-secret"
  end

  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_voice_client_secret_minter = Rails.configuration.x.voice_client_secret_minter
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Rails.configuration.x.voice_client_secret_minter = @original_voice_client_secret_minter
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "a Leader answers a card by voice and can return to typing" do
    project = projects(:community_meal)
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should happen after cooking?",
          "options" => [ "Serve", "Clean", "Pack leftovers" ]
        },
        added: [
          {
            "kind" => "task",
            "fields" => {
              "title" => "Cook the meal together",
              "details" => "Prepare the meal as one kitchen team."
            }
          }
        ]
      )
    ])
    Rails.configuration.x.voice_client_secret_minter = FakeVoiceClientSecretMinter.new
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.add_init_script(script: FAKE_VOICE_BROWSER)
    end
    sign_in_leader_in_browser
    post_planner = project.planner_sessions.create!(
      started_by: people(:leader),
      description: "Prepare the neighborhood meal.",
      current_card: {
        "question" => "How should the Team prepare?",
        "options" => [ "Cook together", "Order food", "Ask for donations" ]
      }
    )

    visit project_planner_session_path(project, post_planner)
    page.execute_script(<<~JS)
      window.__voiceScripts = [
        { question: "How should the Team prepare?", answer: "We'll cook together" }
      ]
    JS
    click_on "Talk It Through"

    assert_text "Your audio is sent to xAI. Describe the work without names or private care details."
    assert_text "How should the Team prepare?"
    assert_text "You: We'll cook together"
    assert_text "What should happen after cooking?", wait: 5
    assert_text "Cook the meal together", wait: 5

    click_on "End Conversation"

    assert_no_selector "[data-voice-planner-target='panel']", visible: true
    assert_button "Talk It Through"
    assert_field "Or answer in your own words"
  end

  test "a Leader answers the build-as-you-go Planner by voice while the preview advances" do
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      planner_response(
        card: {
          "question" => "What should this workday accomplish?",
          "options" => [ "Repair the playground", "Prepare the garden", "Clean the building" ]
        }
      ),
      planner_response(
        card: {
          "question" => "Who should the work serve?",
          "options" => [ "Families", "Neighbors", "The whole church" ]
        },
        added: [
          {
            "kind" => "task",
            "source_key" => "confirm-crew",
            "fields" => {
              "title" => "Confirm volunteer crew",
              "details" => "Invite an open crew for the repair work.",
              "due_on" => "2027-04-09"
            }
          }
        ]
      ),
      planner_response(finished: true)
    ])
    Rails.configuration.x.voice_client_secret_minter = FakeVoiceClientSecretMinter.new
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.add_init_script(script: FAKE_VOICE_BROWSER)
    end
    sign_in_leader_in_browser

    visit new_project_path
    click_button "Workday"
    assert_text "What should this workday accomplish?"
    page.execute_script(<<~JS)
      window.__voiceScripts = [
        { question: "What should this workday accomplish?", answer: "Repair the playground" }
      ]
    JS

    click_on "Talk It Through"

    assert_no_selector "[data-voice-planner-target='questionnaire']", visible: true
    assert_selector ".voice-orb", visible: true
    assert_text "Got it, adding that to your plan.", wait: 5
    assert_text "Confirm volunteer crew", wait: 5
    assert_selector "[data-voice-planner-target='questionnaire']", text: "Who should the work serve?", visible: :all, wait: 5
    assert page.evaluate_script(<<~JS)
      (() => {
        const outputIndex = window.__voiceEvents.findIndex((event) =>
          event.type === "conversation.item.create" && event.item?.type === "function_call_output"
        )
        const responseIndex = window.__voiceEvents.findIndex((event, index) =>
          index > outputIndex && event.type === "response.create"
        )
        return outputIndex >= 0 && responseIndex > outputIndex
      })()
    JS

    click_on "End Conversation"

    assert_selector "[data-voice-planner-target='questionnaire']", visible: true
    assert_text "Who should the work serve?"
  end

  private
    def sign_in_leader_in_browser
      leader = people(:leader)
      token = leader.generate_token_for(:sign_in)
      visit sign_in_link_path(token)
      click_on "Sign In"
      assert_selector "[data-signed-in-as]", text: "Leo Leader"
    end

    def planner_response(card: nil, finished: false, added: [], removed_ids: [])
      Planner::Response.new(card:, finished:, added:, removed_ids:)
    end
end
