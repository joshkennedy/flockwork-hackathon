require "application_system_test_case"

class PlannerVoiceSystemTest < ApplicationSystemTestCase
  FAKE_VOICE_BROWSER = <<~JS
    window.__voiceEvents = []
    window.__voiceAnswered = false
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
        if (event.type !== "response.create" || window.__voiceAnswered) return

        window.__voiceAnswered = true
        window.setTimeout(() => {
          this.onmessage({ data: JSON.stringify({
            type: "response.output_audio_transcript.delta",
            delta: "How should the Team prepare?"
          }) })
          this.onmessage({ data: JSON.stringify({
            type: "conversation.item.input_audio_transcription.completed",
            transcript: "We'll cook together"
          }) })
          this.onmessage({ data: JSON.stringify({
            type: "response.function_call_arguments.done",
            name: "answer_card",
            call_id: "voice-call-28",
            arguments: JSON.stringify({ answer: "We'll cook together" })
          }) })
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
    click_on "Talk It Through"

    assert_text "Voice planning: talk about the work, not people."
    assert_text "How should the Team prepare?"
    assert_text "You: We'll cook together"
    assert_text "What should happen after cooking?", wait: 5
    assert_text "Cook the meal together", wait: 5

    click_on "End Conversation"

    assert_no_selector "[data-voice-planner-target='panel']", visible: true
    assert_button "Talk It Through"
    assert_field "Or answer in your own words"
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
