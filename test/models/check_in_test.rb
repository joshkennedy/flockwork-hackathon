require "test_helper"

class CheckInTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:st_example)
    @person = people(:volunteer)
    @leader = people(:leader)
  end

  test "a check-in cannot be dated in the future or belong to another Organization" do
    future = CheckIn.new(organization: @organization, person: @person, checked_in_by: @leader, on: Date.current + 1)
    other = CheckIn.new(organization: organizations(:grace_fellowship), person: @person, checked_in_by: @leader, on: Date.current)

    assert_not future.valid?
    assert_includes future.errors[:on], "cannot be in the future"
    assert_not other.valid?
    assert_includes other.errors[:person], "must belong to the same church"
  end

  test "the latest check-in is the one with the latest date, and the later record wins a tie" do
    CheckIn.create!(organization: @organization, person: @person, checked_in_by: @leader, on: Date.current - 40, note: nil)
    recent = CheckIn.create!(organization: @organization, person: @person, checked_in_by: @leader, on: Date.current - 3)
    same_day = CheckIn.create!(organization: @organization, person: @person, checked_in_by: people(:admin), on: Date.current - 3)

    latest = CheckIn.latest_by_person([ @person.id ])[@person.id]

    assert_equal same_day, latest
    assert_not_equal recent, latest
  end

  test "someone checked in within the window is out of the needs-a-check-in list, and drops back in after it" do
    overextended_person = people(:volunteer)
    projects(:building_cleanup).memberships.create!(person: overextended_person, role: :volunteer) unless projects(:building_cleanup).memberships.exists?(person: overextended_person)
    third = @organization.projects.create!(name: "Neighborhood Visits", owner: people(:other_leader))
    third.memberships.create!(person: overextended_person, role: :volunteer)

    assert_includes Oversight.needs_check_in(@organization, on: Date.current), overextended_person

    CheckIn.create!(organization: @organization, person: overextended_person, checked_in_by: @leader, on: Date.current - (CheckIn::RECENT_DAYS - 1))
    assert_not_includes Oversight.needs_check_in(@organization, on: Date.current), overextended_person

    assert_includes Oversight.needs_check_in(@organization, on: Date.current + 2), overextended_person
  end

  test "a note is capped" do
    check_in = CheckIn.new(organization: @organization, person: @person, on: Date.current, note: "x" * (CheckIn::NOTE_LIMIT + 1))

    assert_not check_in.valid?
  end
end
