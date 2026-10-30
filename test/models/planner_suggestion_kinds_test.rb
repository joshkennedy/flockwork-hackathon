require "test_helper"

class PlannerSuggestionKindsTest < ActiveSupport::TestCase
  test "provider schema covers every kind and its exact fields" do
    variants = Planner::SuggestionKinds.provider_schema.fetch(:anyOf)

    assert_equal %w[booking enable_tool list purchase schedule_item slot_run task],
      variants.map { |variant| variant.dig(:properties, :kind, :enum).sole }.sort
    assert_equal [ "tool" ], schema_fields(variants, "enable_tool")
    assert_equal %w[details due_in_days role title], schema_fields(variants, "task").sort
    assert_equal %w[day_offset ends_at location starts_at title], schema_fields(variants, "schedule_item").sort
    assert_equal %w[capacity end_day_offset label start_day_offset time], schema_fields(variants, "slot_run").sort
    assert_equal %w[description estimated_dollars role], schema_fields(variants, "booking").sort
    assert_equal %w[description estimated_dollars role], schema_fields(variants, "purchase").sort
    assert_equal %w[columns name], schema_fields(variants, "list").sort
  end

  private
    def schema_fields(variants, kind)
      variant = variants.find { |candidate| candidate.dig(:properties, :kind, :enum) == [ kind ] }
      variant.dig(:properties, :fields, :properties).keys.map(&:to_s)
    end
end
