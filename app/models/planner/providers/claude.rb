module Planner
  module Providers
    class Claude
      MODEL = "claude-sonnet-5-5"
      SYSTEM_PROMPT = <<~PROMPT.freeze
        You are the Flockwork Planner. Ask one question at a time and provide 3 to 5 short answer options.
        Build Task Suggestions for the Project as you learn. Propose open roles such as "2 drivers", never people.
        Never request, infer, or name a person. Respond only with data matching the provided schema.
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
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                id: { type: "string", format: "uuid" },
                kind: { type: "string", enum: [ "task" ] },
                fields: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    title: { type: "string" },
                    details: { type: "string" },
                    due_in_days: { type: [ "integer", "null" ] },
                    role: { type: [ "string", "null" ] }
                  },
                  required: %w[title details]
                },
                status: { type: "string", enum: %w[proposed kept edited dropped] }
              },
              required: %w[id kind fields status]
            }
          }
        },
        required: %w[card finished suggestions]
      }.freeze

      def call(context)
        message = RubyLLM.chat(model: MODEL, provider: :anthropic)
          .with_instructions(SYSTEM_PROMPT)
          .with_schema(RESPONSE_SCHEMA)
          .ask(JSON.generate(context))
        parsed = message.parsed
        card = parsed.fetch("card")
        finished = parsed.fetch("finished")
        raise ArgumentError, "Finished Planner responses must have no card" unless finished == card.nil?

        Planner::Response.new(
          card:,
          finished:,
          suggestions: parsed.fetch("suggestions")
        )
      end
    end
  end
end
