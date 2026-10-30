module Planner
  class VoiceSession
    MODEL = "grok-voice-latest"
    TOOLS = [
      {
        type: "function",
        name: "answer_card",
        description: "Submit the Leader's answer to the current Planner card in their own words.",
        parameters: {
          type: "object",
          additionalProperties: false,
          properties: {
            answer: {
              type: "string",
              description: "The Leader's answer in their own words."
            }
          },
          required: [ "answer" ]
        }
      }
    ].freeze

    def initialize(planner_session)
      @planner_session = planner_session
    end

    def payload
      {
        client_secret: Rails.configuration.x.voice_client_secret_minter.call,
        model: MODEL,
        instructions: Planner::ContextBuilder.new(planner_session).voice_instructions,
        tools: TOOLS
      }
    end

    private
      attr_reader :planner_session
  end
end
