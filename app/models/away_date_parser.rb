# Turns one person's sentence about being away into proposed date ranges. Nothing is saved here:
# the person confirms the ranges on Profile first. Any failure raises Unavailable, and the manual date fields remain.
class AwayDateParser
  class Unavailable < StandardError; end

  PROMPT = <<~PROMPT.freeze
    You turn one volunteer's sentence about when they are away or can't serve into date ranges.
    Today is %{today}. Resolve phrases such as "next month", "first Sunday of August" or "the 14th" against today.
    Reply with only one JSON object, no prose:
    {"ranges": [{"starts_on": "YYYY-MM-DD", "ends_on": "YYYY-MM-DD"}], "unclear": false}
    Both ends are inclusive, and a single day has the same starts_on and ends_on. Return "ranges": [] and "unclear": true when no date range is clear.
    Return only dates. Never add reasons, names or other details.
  PROMPT

  def self.call(text, today: Date.current) = new(text, today: today).call

  # Accepts the model's reply and returns [{ starts_on:, ends_on: }], or raises Unavailable.
  def self.from_reply(content)
    json = JSON.parse(content.to_s[/\{.*\}/m] || raise(Unavailable, "No JSON in the reply"))
    ranges = Array(json["ranges"]).first(10).map do |range|
      starts_on = Date.iso8601(range.fetch("starts_on"))
      ends_on = Date.iso8601(range.fetch("ends_on"))
      raise Unavailable, "A range ends before it starts" if ends_on < starts_on

      { starts_on: starts_on, ends_on: ends_on }
    end
    raise Unavailable, "No clear dates" if ranges.empty?

    ranges
  rescue JSON::ParserError, KeyError, TypeError, ArgumentError => error
    raise Unavailable, error.message
  end

  def initialize(text, today:)
    @text = text
    @today = today
  end

  def call
    raise Unavailable, "No OpenRouter key is configured" if ENV["OPENROUTER_API_KEY"].blank?

    DemoAiLimit.consume!(Current.organization)
    message = RubyLLM.context { |config| config.request_timeout = 20 }
      .chat(model: model, provider: :openrouter, assume_model_exists: true)
      .with_instructions(format(PROMPT, today: @today.iso8601))
      # The model reasons before it answers, and a small cap leaves no room for the JSON; the Planner uses 4,000 for the same reason.
      .with_max_output_tokens(4_000)
      .ask(@text.to_s.squish.first(500))
    self.class.from_reply(message.content)
  rescue DemoAiLimit::Exceeded => error
    raise Unavailable, error.message
  rescue Unavailable
    raise
  rescue StandardError => error
    Rails.logger.warn("[AwayDateParser] #{error.class}: #{error.message}")
    raise Unavailable, error.message
  end

  private
    def model
      ENV.fetch("AWAY_LLM_MODEL", "anthropic/claude-haiku-5.5")
    end
end
