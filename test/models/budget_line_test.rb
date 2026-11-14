require "test_helper"

class BudgetLineTest < ActiveSupport::TestCase
  test "format_cents and cents_from_dollars round-trip without float drift" do
    assert_equal 1999, BudgetLine.cents_from_dollars("19.99")
    assert_equal "$19.99", BudgetLine.format_cents(1999)
    assert_equal 123_456, BudgetLine.cents_from_dollars("1,234.56")
    assert_equal "$1,234.56", BudgetLine.format_cents(123_456)
  end

  test "an estimate can be unknown and totals skip it" do
    unknown = projects(:community_meal).budget_lines.build(kind: :purchase, description: "Paint", estimated_cents: nil)
    known = projects(:community_meal).budget_lines.build(kind: :purchase, description: "Brushes", estimated_cents: 2_500)

    assert_predicate unknown, :valid?
    assert_equal 2_500, BudgetLine.estimated_total_cents([ unknown, known ])
  end

  test "estimated and actual totals exclude cancelled lines" do
    project = projects(:community_meal)
    active = project.budget_lines.build(kind: :purchase, description: "Brushes", estimated_cents: 2_500, actual_cents: 2_000)
    cancelled = project.budget_lines.build(kind: :purchase, description: "Unused paint", estimated_cents: 10_000, actual_cents: 8_000, status: :cancelled)

    assert_equal 2_500, BudgetLine.estimated_total_cents([ active, cancelled ])
    assert_equal 2_000, BudgetLine.actual_total_cents([ active, cancelled ])
  end

  test "a cost that is not a dollar amount is rejected with a fix" do
    line = projects(:community_meal).budget_lines.build(kind: :booking, description: "Bus", estimated: "abc", actual: "$1,200")

    assert_not line.valid?
    assert_includes line.errors.full_messages, "Estimated cost must be a dollar amount, like 120 or 45.50."
    assert_equal "abc", line.estimated
    assert_equal 120_000, line.actual_cents
  end
end
