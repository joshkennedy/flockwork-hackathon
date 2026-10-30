require "test_helper"

class BudgetLineTest < ActiveSupport::TestCase
  test "format_cents and cents_from_dollars round-trip without float drift" do
    assert_equal 1999, BudgetLine.cents_from_dollars("19.99")
    assert_equal "$19.99", BudgetLine.format_cents(1999)
    assert_equal 123_456, BudgetLine.cents_from_dollars("1,234.56")
    assert_equal "$1,234.56", BudgetLine.format_cents(123_456)
  end
end
