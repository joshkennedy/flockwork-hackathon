require "test_helper"

class PlannerSuggestionKindsTest < ActiveSupport::TestCase
  MERGED_FIELD_NAMES = %w[
    capacity columns day_offset description details due_in_days end_day_offset ends_at
    estimated_dollars label location name role start_day_offset starts_at time title tool
  ].freeze

  test "provider schema is one flat object with merged nullable fields" do
    schema = Planner::SuggestionKinds.provider_schema
    json = JSON.generate(schema)

    assert_equal "object", schema.fetch(:type)
    assert_equal Planner::SuggestionKinds::KINDS.keys.sort, schema.dig(:properties, :kind, :enum).sort
    assert_equal MERGED_FIELD_NAMES, schema.dig(:properties, :fields, :properties).keys.map(&:to_s).sort
    assert_equal [], schema.dig(:properties, :fields, :required)
    refute_includes json, "anyOf"
    refute_includes json, "pattern"
  end
end
