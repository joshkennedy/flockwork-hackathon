require "test_helper"

class PlannerProvidersLlmTest < ActiveSupport::TestCase
  test "response contract contains only Planner deltas" do
    assert_equal %i[card finished added removed_ids], Planner::Response.members

    schema = Planner::Providers::Llm::RESPONSE_SCHEMA
    assert_equal %i[card finished added removed_ids], schema.fetch(:properties).keys
    assert_equal %w[card finished added removed_ids], schema.fetch(:required)
    assert_equal Planner::SuggestionKinds.provider_schema, schema.dig(:properties, :added, :items)
    assert_equal({ type: "string" }, schema.dig(:properties, :removed_ids, :items))
    refute_includes JSON.generate(schema), "suggestions"
  end

  test "system prompt tells the model to return only new and removed Suggestions" do
    prompt = Planner::Providers::Llm::SYSTEM_PROMPT

    assert_includes prompt,
      "added contains only NEW suggestions this answer implies; removed_ids lists ids from " \
        "current_suggestions the answer rules out; never repeat existing suggestions."
    assert_includes prompt, "Ask one question at a time and provide 3 to 5 short answer options."
    assert_includes prompt, "Propose open roles such as \"2 drivers\", never people."
  end

  test "build-as-you-go prompts require explicit item removals" do
    [ Planner::Providers::Llm::MEAL_PROMPT, Planner::Providers::Llm::GENERAL_PROMPT ].each do |prompt|
      assert_includes prompt, "Include an item's id in removed_ids only when an answer explicitly rules it out."
      assert_includes prompt, "Omission from added never removes saved draft work."
    end
  end

  test "resolves provider and model from ENV with defaults" do
    with_planner_llm_env("PLANNER_LLM_PROVIDER" => nil, "PLANNER_LLM_MODEL" => nil) do
      llm = Planner::Providers::Llm.new
      assert_equal "openrouter", llm.llm_provider
      assert_equal "anthropic/claude-sonnet-5.5", llm.llm_model
    end

    with_planner_llm_env(
      "PLANNER_LLM_PROVIDER" => "xai",
      "PLANNER_LLM_MODEL" => "grok-3"
    ) do
      llm = Planner::Providers::Llm.new
      assert_equal "xai", llm.llm_provider
      assert_equal "grok-3", llm.llm_model
    end
  end

  test "only the first card of a build-as-you-go Planner skips the reasoning pass" do
    card = { "question" => "Which meals?", "options" => %w[Dinner Lunch Brunch] }
    content = JSON.generate(card:, finished: false, added: [], removed_ids: [])
    chat = RecordingChat.new(content)
    llm = Planner::Providers::Llm.new

    with_ruby_llm_chat(chat) do
      llm.call("flow_version" => 2, "questions_answered" => 0)
      assert_equal :low, chat.effort
      assert_equal 1, chat.calls

      chat.effort = nil
      llm.call("flow_version" => 2, "questions_answered" => 1)
      assert_nil chat.effort
    end
  end

  test "a provider call that outlives the step budget fails instead of waiting" do
    content = JSON.generate(card: nil, finished: true, added: [], removed_ids: [])

    with_planner_llm_env("PLANNER_LLM_BUDGET_SECONDS" => "0.05") do
      with_ruby_llm_chat(SlowChat.new(content)) do
        assert_raises(Planner::Providers::Llm::BudgetExceeded) do
          Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 1)
        end
      end
    end
  end

  test "streams complete card and items to the caller before the final parse" do
    card = { "question" => "Which meals?", "options" => %w[Dinner Lunch Brunch] }
    item = { "kind" => "slot_run", "source_key" => "meal-slots", "fields" => { "label" => "Dinner" } }
    content = JSON.generate(card:, finished: false, added: [ item ], removed_ids: [])
    partials = []

    response = with_ruby_llm_chat(StreamingChat.new(content, chunk_size: 9)) do
      Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 1) { |partial| partials << partial }
    end

    assert_operator partials.size, :>, 2
    assert_equal({ card:, added: [ item ] }, partials.last)
    assert_equal "Which meals?", response.card.fetch("question")
  end

  test "parses the first JSON object before trailing markup" do
    content = JSON.generate(card: nil, finished: true, added: [], removed_ids: []) +
      "</parameter>{\"ignored\":true}"

    response = with_ruby_llm_chat(RecordingChat.new(content)) do
      Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 1)
    end

    assert response.finished
  end

  test "parses JSON preceded by prose" do
    content = "Here is the plan:\n" + JSON.generate(card: nil, finished: true, added: [], removed_ids: [])

    response = with_ruby_llm_chat(RecordingChat.new(content)) do
      Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 1)
    end

    assert response.finished
  end

  test "parses nested braces inside JSON strings" do
    card = {
      "question" => "Should {\"label\":\"Dinner\"} stay literal?",
      "options" => [ "A } brace", "A { brace", "An escaped quote: \"yes\"" ]
    }
    content = JSON.generate(card:, finished: false, added: [], removed_ids: [])

    response = with_ruby_llm_chat(RecordingChat.new(content)) do
      Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 1)
    end

    assert_equal card, response.card
  end

  test "raises JSON parser errors for truncated responses" do
    content = '{"card":null,"finished":true,"added":[],"removed_ids":['

    assert_raises(JSON::ParserError) do
      with_ruby_llm_chat(RecordingChat.new(content)) do
        Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 1)
      end
    end
  end

  test "retries one transient parse failure and logs response length only" do
    valid = JSON.generate(card: nil, finished: true, added: [], removed_ids: [])
    chat = RecordingChat.new([ "private response content", valid ])
    io = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)

    response = with_ruby_llm_chat(chat) do
      Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 1)
    end

    assert response.finished
    assert_equal 2, chat.calls
    assert_includes io.string, "response_length=24"
    refute_includes io.string, "private response content"
  ensure
    Rails.logger = original_logger
  end

  test "logs the per-call usage at debug level, including cache reads and writes" do
    tokens = Struct.new(:input, :output, :cache_read, :cache_write, :thinking).new(1200, 300, 900, 0, 40)
    content = JSON.generate(card: nil, finished: true, added: [], removed_ids: [])
    io = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io).tap { |logger| logger.level = Logger::DEBUG }

    with_ruby_llm_chat(StreamingChat.new(content, chunk_size: 40, tokens:)) do
      Planner::Providers::Llm.new.call("flow_version" => 2, "questions_answered" => 2) { |_| }
    end

    assert_includes io.string, "input=1200 output=300 cache_read=900 cache_write=0"
  ensure
    Rails.logger = original_logger
  end

  private

  class RecordingChat
    attr_accessor :effort
    attr_reader :calls

    def initialize(content)
      @content = content
      @calls = 0
    end

    def with_instructions(*, **) = self
    def with_max_output_tokens(_) = self
    def with_thinking(effort:) = tap { @effort = effort }

    def ask(_)
      @calls += 1
      content = @content.is_a?(Array) ? @content.fetch(@calls - 1) : @content
      Struct.new(:content, :tokens).new(content, nil)
    end
  end

  class StreamingChat < RecordingChat
    def initialize(content, chunk_size:, tokens: nil)
      super(content)
      @chunk_size = chunk_size
      @tokens = tokens
    end

    def ask(_, &block)
      @calls += 1
      @content.scan(/.{1,#{@chunk_size}}/m).each { |text| block.call(Struct.new(:content).new(text)) } if block
      Struct.new(:content, :tokens).new(@content, @tokens)
    end
  end

  def with_ruby_llm_chat(chat)
    singleton = RubyLLM.singleton_class
    singleton.alias_method(:original_context_for_test, :context)
    singleton.define_method(:context) { |&| ChatContext.new(chat) }
    yield
  ensure
    singleton.alias_method(:context, :original_context_for_test)
    singleton.remove_method(:original_context_for_test)
  end

  ChatContext = Struct.new(:chat_double) do
    def chat(**) = chat_double
  end

  class SlowChat < RecordingChat
    def ask(_, &)
      sleep 1
      super
    end
  end

  def with_planner_llm_env(changes)
    keys = %w[PLANNER_LLM_PROVIDER PLANNER_LLM_MODEL PLANNER_LLM_BUDGET_SECONDS]
    saved = keys.index_with { |key| ENV.key?(key) ? ENV[key] : :absent }
    changes.each do |key, value|
      key = key.to_s
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    saved.each do |key, value|
      value == :absent ? ENV.delete(key) : ENV[key] = value
    end
  end
end
