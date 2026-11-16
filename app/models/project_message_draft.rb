require "timeout"

class ProjectMessageDraft
  class Unavailable < StandardError; end
  class LimitReached < Unavailable; end
  Draft = Data.define(:title, :body)
  PURPOSES = { "announcement" => "Announce this Project", "open_spots" => "Ask for help with open spots" }.freeze

  INSTRUCTIONS = <<~PROMPT.freeze
    Draft a short church Project message from the supplied counts and dates only.
    Return JSON with plain text title and body strings. Use {{project}} for the Project name.
    Never invent people, names, dates, numbers, reasons, promises, or completed work.
    Do not mention private care information. Do not include HTML or Markdown formatting.
    Ask readers to review the Project and choose a spot when asking for help. Do not claim any action was sent.
  PROMPT

  def self.provider
    Llm.new
  end

  def initialize(project, provider: self.class.provider)
    @project = project
    @provider = provider
  end

  def call(purpose)
    raise Unavailable, "Choose a draft type." unless PURPOSES.key?(purpose)

    risk = ProjectRisk.new(@project)
    if purpose == "open_spots" && (!@project.active? || risk.open_spots.zero?)
      raise Unavailable, "There are no open spots in the next seven days. Choose an announcement instead."
    end
    facts = {
      "request" => Planner::NameRedactor.new(@project.organization).call(PURPOSES.fetch(purpose)),
      "project_name" => "{{project}}",
      "starts_on" => @project.starts_on&.strftime("%B %-d, %Y"),
      "ends_on" => @project.ends_on&.strftime("%B %-d, %Y"),
      "open_spots_next_7_days" => risk.open_spots
    }
    DemoAiLimit.consume!(@project.organization)
    response = @provider.call(facts)
    title = response.fetch("title")
    body = response.fetch("body")
    unless title.is_a?(String) && body.is_a?(String) && title.present? && body.present? && title.length <= 160 && body.length <= 4_000
      raise Unavailable, "The draft could not be read. Try again or write a message in the Project."
    end
    allowed_numbers = facts.except("request").to_json.scan(/\d+/).map(&:to_i)
    unless "#{title} #{body}".scan(/\d+/).all? { |number| allowed_numbers.include?(number.to_i) }
      raise Unavailable, "The draft included numbers that could not be verified. Try again or write a message in the Project."
    end
    Draft.new(title: title.gsub("{{project}}", @project.name), body: body.gsub("{{project}}", @project.name))
  rescue DemoAiLimit::Exceeded => error
    raise LimitReached, error.message
  rescue Unavailable
    raise
  rescue StandardError => error
    Rails.logger.warn("[ProjectMessageDraft] #{error.class}")
    raise Unavailable, "Drafting is unavailable right now. Try again or write a message in the Project."
  end

  class Llm
    PROVIDER_KEYS = { "openrouter" => "OPENROUTER_API_KEY", "anthropic" => "ANTHROPIC_API_KEY", "xai" => "XAI_API_KEY" }.freeze

    def call(facts)
      provider = ENV.fetch("MESSAGE_DRAFT_LLM_PROVIDER", "openrouter")
      key = PROVIDER_KEYS[provider]
      raise Unavailable, "Drafting is unavailable right now. You can write a message in the Project." unless key && ENV[key].present?
      budget = Float(ENV.fetch("MESSAGE_DRAFT_LLM_BUDGET_SECONDS", "20"))
      raise Unavailable, "Drafting is unavailable right now. You can write a message in the Project." unless budget.positive? && budget.finite?

      Timeout.timeout(budget) do
        reply = RubyLLM.context { |config| config.request_timeout = budget }
          .chat(model: ENV.fetch("MESSAGE_DRAFT_LLM_MODEL", "anthropic/claude-sonnet-5.5"), provider: provider.to_sym, assume_model_exists: true)
          .with_instructions(INSTRUCTIONS)
          .with_max_output_tokens(2_000)
          .ask(JSON.generate(facts))
        JSON.parse(reply.content.to_s[/\{.*\}/m] || raise(Unavailable, "The draft could not be read. Try again."))
      end
    end
  end
end
