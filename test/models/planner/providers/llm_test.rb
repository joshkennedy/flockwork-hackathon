require "test_helper"

class PlannerProvidersLlmTest < ActiveSupport::TestCase
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
