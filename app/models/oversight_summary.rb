# One plain sentence per Oversight card, built from counts and dates only. The model sees an opaque id and
# these facts, never a name or email. Its reply is accepted only if every number and date in it was passed in.
class OversightSummary
  class Rejected < StandardError; end

  TTL = 30.days
  FAILED = false
  MAX_LENGTH = 200
  # Words that would turn a count into a judgment about someone's state. A reply using one is dropped.
  JUDGMENT_WORDS = /burn|struggl|tired|exhaust|feel|mood|faith|spirit|pray|grie|sad|lonel|overwhelm|stress|worr|health|sick|divorc|family|wellbeing|well-being|doing well|unwell|anx|depress|crisis|troubl|problem|concern|pastor|should|need to/i

  INSTRUCTIONS = <<~PROMPT.freeze
    You write one plain sentence for a church Oversight card that summarizes how many Active Projects one volunteer serves on and when they last checked in.
    Use only the facts in the JSON. You may quote only the numbers and dates in the facts. Do not add other numbers.
    Do not describe feelings, wellbeing, faith or spiritual state, and do not judge or advise. Do not name anyone.
    Follow this style: "Serving on <count> Active Projects since <Month>, <last check-in phrase>." Write dates as month and day, never as 2026-09-20.
    Reply with only one JSON object and no prose: {"sentence": "..."}
  PROMPT

  class << self
    def facts_for(person, last_check_in: nil)
      since = person.memberships.joins(:project).merge(Project.active).minimum(:created_at)
      {
        "serving_load" => Oversight.serving_load(person),
        "serving_since" => since&.to_date&.iso8601,
        "last_check_in_on" => last_check_in&.on&.iso8601
      }
    end

    # The sentence for the card right now: the cached AI sentence for these exact facts, else the template.
    # A miss queues one generation for these facts; the template stays on screen until it lands.
    def line(person, facts)
      key = key_for(person, facts)
      cached = Rails.cache.read(key)
      return cached if cached.is_a?(String)

      if cached.nil? && ENV["OPENROUTER_API_KEY"].present? && Rails.cache.write("#{key}/pending", true, expires_in: 5.minutes, unless_exist: true)
        OversightSummaryJob.perform_later(key, facts)
      end
      template(facts)
    end

    def key_for(person, facts)
      "oversight-summary/#{person.id}/#{Digest::SHA256.hexdigest(facts.to_json)[0, 16]}"
    end

    # Deterministic, from the same facts. Used whenever AI is off, unavailable or its reply is rejected.
    def template(facts)
      load = facts["serving_load"].to_i
      since = parse_date(facts["serving_since"])
      last = parse_date(facts["last_check_in_on"])

      sentence = +"Serving on #{load} #{"Active Project".pluralize(load)}"
      sentence << " since #{since.strftime("%B")}#{" #{since.year}" unless since.year == Date.current.year}" if since
      sentence << (last ? ", last check-in #{last.strftime("%b %-d")}" : ", no check-in logged")
      "#{sentence}."
    end

    def payload(facts)
      "Facts for p1: #{facts.to_json}"
    end

    # Accepts the model's reply only when it stays inside the facts. Anything else raises Rejected.
    def from_reply(content, facts)
      json = JSON.parse(content.to_s[/\{.*\}/m] || raise(Rejected, "No JSON in the reply"))
      sentence = json.fetch("sentence").to_s.squish
      raise Rejected, "Empty or too long" if sentence.blank? || sentence.length > MAX_LENGTH
      raise Rejected, "Contains an address" if sentence.include?("@")
      raise Rejected, "Quotes a number that was not passed in" unless sentence.scan(/\d+/).all? { |number| allowed_numbers(facts).include?(number.to_i) }
      raise Rejected, "Judges the person" if sentence.match?(JUDGMENT_WORDS)

      sentence
    rescue JSON::ParserError, KeyError, TypeError => error
      raise Rejected, error.message
    end

    # Runs in OversightSummaryJob. Returns nil when AI is off, the call fails, or the reply is rejected.
    def generate(facts)
      return if ENV["OPENROUTER_API_KEY"].blank?

      message = RubyLLM.context { |config| config.request_timeout = 20 }
        .chat(model: model, provider: :openrouter, assume_model_exists: true)
        .with_instructions(INSTRUCTIONS)
        .with_max_output_tokens(4_000)
        .ask(payload(facts))
      from_reply(message.content, facts)
    rescue StandardError => error
      Rails.logger.warn("[OversightSummary] #{error.class}: #{error.message}")
      nil
    end

    private
      def model
        ENV.fetch("OVERSIGHT_LLM_MODEL", "anthropic/claude-haiku-5.5")
      end

      def allowed_numbers(facts)
        dates = [ parse_date(facts["serving_since"]), parse_date(facts["last_check_in_on"]) ].compact
        ([ facts["serving_load"].to_i ] + dates.flat_map { |date| [ date.day, date.month, date.year ] })
      end

      def parse_date(value)
        Date.iso8601(value) if value.present?
      end
  end
end
