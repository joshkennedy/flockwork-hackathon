module Planner
  module Providers
    class Llm
      SYSTEM_PROMPT = <<~PROMPT.freeze
        You are the Flockwork Planner. Ask one question at a time and provide 3 to 5 short answer options.
        Build Suggestions for Tools, Tasks, Schedule items, Slot runs, Bookings, Purchases, and Lists as you learn.
        Day offsets are relative to the Project start date. Propose open roles such as "2 drivers", never people.
        Never request, infer, or name a person. Respond with only one JSON object matching the schema below, no prose or code fences.
      PROMPT
      RESPONSE_SCHEMA = {
        type: "object",
        additionalProperties: false,
        properties: {
          card: {
            anyOf: [
              {
                type: "object",
                additionalProperties: false,
                properties: {
                  question: { type: "string" },
                  options: { type: "array", minItems: 3, maxItems: 5, items: { type: "string" } }
                },
                required: %w[question options]
              },
              { type: "null" }
            ]
          },
          finished: { type: "boolean" },
          suggestions: {
            type: "array",
            items: Planner::SuggestionKinds.provider_schema
          }
        },
        required: %w[card finished suggestions]
      }.freeze

      def call(context)
        # The schema goes in the prompt, not as a response format: Anthropic's constrained decoding can't
        # compile it in time. The shape is checked here and Suggestions are sanitized per kind on ingest.
        message = RubyLLM.chat(model: llm_model, provider: llm_provider.to_sym, assume_model_exists: true)
          .with_instructions("#{SYSTEM_PROMPT}\nJSON schema:\n#{JSON.generate(RESPONSE_SCHEMA)}")
          # Providers default to the model's full output window, which is slow and can exceed account credit.
          .with_max_output_tokens(4_000)
          .ask(JSON.generate(context))
        parsed = JSON.parse(message.content.to_s[/\{.*\}/m] || raise(ArgumentError, "Planner response had no JSON"))
        card = parsed.fetch("card")
        finished = parsed.fetch("finished")
        raise ArgumentError, "Finished Planner responses must have no card" unless finished == card.nil?
        raise ArgumentError, "Cards need 3 to 5 options" if card && !card.fetch("options").size.between?(3, 5)

        Planner::Response.new(
          card:,
          finished:,
          suggestions: parsed.fetch("suggestions")
        )
      end

      def llm_provider
        ENV.fetch("PLANNER_LLM_PROVIDER", "openrouter")
      end

      def llm_model
        ENV.fetch("PLANNER_LLM_MODEL", "anthropic/claude-sonnet-5.5")
      end
    end
  end
end
