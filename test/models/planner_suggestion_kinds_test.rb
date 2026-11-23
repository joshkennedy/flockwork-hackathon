require "test_helper"

class PlannerSuggestionKindsTest < ActiveSupport::TestCase
  MERGED_FIELD_NAMES = %w[
    capacity claim_prompt columns day_offset days description details due_in_days end_day_offset ends_at
    estimated_dollars label location name role schedule_item_source_key start_day_offset starts_at time title tool
  ].freeze

  test "provider schema is one flat added item without session-owned fields" do
    schema = Planner::SuggestionKinds.provider_schema
    json = JSON.generate(schema)

    assert_equal "object", schema.fetch(:type)
    assert_equal %i[kind fields], schema.fetch(:properties).keys
    assert_equal %w[kind fields], schema.fetch(:required)
    assert_equal Planner::SuggestionKinds::KINDS.keys.sort, schema.dig(:properties, :kind, :enum).sort
    assert_equal MERGED_FIELD_NAMES, schema.dig(:properties, :fields, :properties).keys.map(&:to_s).sort
    assert_equal [], schema.dig(:properties, :fields, :required)
    refute_includes json, "id"
    refute_includes json, "status"
    refute_includes json, "anyOf"
    refute_includes json, "pattern"
  end

  test "legacy slot run suggestions create prompted Slots" do
    project = projects(:community_meal)
    label = "Potluck sides"

    assert_difference "project.slots.count", 2 do
      Planner::SuggestionKinds.create!(project, {
        "kind" => "slot_run",
        "fields" => {
          "label" => label,
          "start_day_offset" => 0,
          "end_day_offset" => 1,
          "time" => "12:00",
          "capacity" => 8,
          "claim_prompt" => "What are you bringing?"
        }
      })
    end

    slots = project.slots.where(label:).order(:date)
    assert_equal [ "What are you bringing?" ], slots.pluck(:claim_prompt).uniq
    assert_includes Planner::SuggestionKinds.permitted_fields, :claim_prompt
  end

  test "budget suggestions without an estimate create lines to estimate later" do
    project = projects(:community_meal)

    %w[booking purchase].each do |kind|
      line = Planner::SuggestionKinds.create!(project, { "kind" => kind, "fields" => { "description" => "Retreat #{kind}" } })

      assert_nil line.estimated_cents
    end
  end
end
