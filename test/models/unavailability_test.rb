require "test_helper"

class UnavailabilityTest < ActiveSupport::TestCase
  setup do
    @person = people(:volunteer)
    @organization = organizations(:st_example)
  end

  test "an away range must end on or after it starts" do
    away = Unavailability.new(organization: @organization, person: @person, starts_on: Date.new(2026, 7, 10), ends_on: Date.new(2026, 7, 9))

    assert_not away.valid?
    assert_includes away.errors[:ends_on], "must be on or after the start date"
  end

  test "an away range belongs to the same Organization as its Person" do
    other = Unavailability.new(organization: organizations(:grace_fellowship), person: @person, starts_on: Date.current, ends_on: Date.current)

    assert_not other.valid?
    assert_includes other.errors[:person], "must belong to the same church"
  end

  test "a note is capped" do
    away = Unavailability.new(organization: @organization, person: @person, starts_on: Date.current, ends_on: Date.current, note: "x" * 201)

    assert_not away.valid?
  end

  test "covering finds ranges that include the date, edges included" do
    away = Unavailability.create!(organization: @organization, person: @person, starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 3, 14))

    assert_includes Unavailability.covering(Date.new(2026, 3, 1)), away
    assert_includes Unavailability.covering(Date.new(2026, 3, 14)), away
    assert_empty Unavailability.covering(Date.new(2026, 3, 15))
  end

  test "range labels show dates, and the year only when it is not this year" do
    travel_to Date.new(2026, 11, 2) do
      same_month = Unavailability.new(starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 3, 14))
      across = Unavailability.new(starts_on: Date.new(2026, 3, 28), ends_on: Date.new(2026, 4, 2))
      last_year = Unavailability.new(starts_on: Date.new(2025, 12, 30), ends_on: Date.new(2026, 1, 2))

      assert_equal "Mar 1 to 14", same_month.range_label
      assert_equal "Mar 28 to Apr 2", across.range_label
      assert_equal "Dec 30, 2025 to Jan 2", last_year.range_label
    end
  end

  test "Leaders and Admins see Away until while the range is on, otherwise Unavailable" do
    away = Unavailability.new(starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 9))

    assert_equal "Away until Nov 9", away.away_label(Date.new(2026, 11, 2))
    assert_equal "Away Nov 1 to 9", away.away_label(Date.new(2026, 10, 1))
  end
end
