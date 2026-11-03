require "test_helper"

class PlannerPartialResponseTest < ActiveSupport::TestCase
  CARD = { "question" => "Which {meal}?", "options" => [ "Dinner \"deluxe\"", "Lunch" ] }.freeze
  ITEM_ONE = { "kind" => "slot_run", "source_key" => "meal-slots", "fields" => { "label" => "Dinner {Sat}" } }.freeze
  ITEM_TWO = { "kind" => "slot_run", "source_key" => "meal-slots-2", "fields" => { "label" => "Tacos" } }.freeze

  test "exposes the card and each added item only once it is complete" do
    json = JSON.pretty_generate(card: CARD, finished: false, added: [ ITEM_ONE, ITEM_TWO ], removed_ids: [])
    partial = Planner::PartialResponse.new

    partial << json[0...json.index('"added"')]
    assert_equal CARD, partial.card
    assert_empty partial.added

    partial << json[json.index('"added"')...json.index('"Tacos"')]
    assert_equal [ ITEM_ONE ], partial.added

    partial << json[json.index('"Tacos"')..]
    assert_equal [ ITEM_ONE, ITEM_TWO ], partial.added
  end

  test "reads nothing from a partial card, number, or string" do
    partial = Planner::PartialResponse.new
    partial << %({"card": {"question": "Which mea)
    assert_nil partial.card
    assert_empty partial.added

    partial << %(l?", "options": ["A", "B", "C"]}, "finished": 12)
    assert_equal({ "question" => "Which meal?", "options" => %w[A B C] }, partial.card)
  end

  test "chunks split at any byte give the same complete values as one parse" do
    json = JSON.generate(card: CARD, finished: false, added: [ ITEM_ONE, ITEM_TWO ], removed_ids: [])
    partial = Planner::PartialResponse.new
    json.each_char { |char| partial << char }

    assert_equal CARD, partial.card
    assert_equal [ ITEM_ONE, ITEM_TWO ], partial.added
  end

  test "a null card and an empty added list are complete with no items" do
    partial = Planner::PartialResponse.new << JSON.generate(card: nil, finished: true, added: [], removed_ids: [])

    assert_nil partial.card
    assert_empty partial.added
  end

  test "added items are read even when the card arrives after them" do
    json = JSON.generate(added: [ ITEM_ONE ], card: CARD, finished: false, removed_ids: [])
    partial = Planner::PartialResponse.new << json

    assert_equal CARD, partial.card
    assert_equal [ ITEM_ONE ], partial.added
  end
end
