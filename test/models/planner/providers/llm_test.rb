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

  private

  def with_planner_llm_env(changes)
    keys = %w[PLANNER_LLM_PROVIDER PLANNER_LLM_MODEL]
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
