require "test_helper"
require_relative "../support/method_stubs"

class OversightAwayTest < ActionDispatch::IntegrationTest
  include MethodStubs

  setup do
    @organization = organizations(:st_example)
    @volunteer = people(:volunteer)
    projects(:building_cleanup).memberships.create!(person: @volunteer, role: :volunteer)
    third = @organization.projects.create!(name: "Neighborhood Visits", owner: people(:other_leader))
    third.memberships.create!(person: @volunteer, role: :volunteer)
    @away = @volunteer.unavailabilities.create!(organization: @organization, starts_on: Date.current - 2, ends_on: Date.current + 6, note: "Private trip details")
  end

  test "someone away today is not flagged overextended and is marked Away until instead" do
    sign_in_as_admin
    get oversight_path

    assert_response :success
    assert_select "[data-overextended-person='Vic Volunteer']", 0
    assert_select "[data-away-person='Vic Volunteer']", text: /Away until #{(Date.current + 6).strftime("%b %-d")}/
  end

  test "the overextended flag returns once the away range ends" do
    travel_to Date.current + 7 do
      sign_in_as_admin
      get oversight_path

      assert_select "[data-overextended-person='Vic Volunteer'][data-serving-load='3']"
      assert_select "[data-away-person='Vic Volunteer']", 0
    end
  end

  test "a Leader sees away dates but never the note, and sees no settings or involvement table" do
    sign_in_as_leader
    get oversight_path

    assert_response :success
    assert_select "[data-away-person='Vic Volunteer']"
    assert_no_match "Private trip details", response.body
    assert_select "input[name='organization[overextended_limit]']", 0
    assert_select "[data-involvement-person]", 0
    assert_select "a[href='#{edit_person_path(@volunteer)}']", 0
  end

  test "the person sees their own note on Profile" do
    sign_in_as_volunteer
    get edit_profile_path

    assert_select "[data-away-range]", text: /Private trip details/
  end

  test "a Volunteer cannot open Oversight" do
    sign_in_as_volunteer
    get oversight_path

    assert_response :not_found
  end

  test "the highlight is a thank-you with plain counts, not a ranking" do
    slot = projects(:community_meal).slots.create!(date: Date.current, label: "Sunday Lunch", capacity: 2)
    SlotClaim.create!(slot: slot, person: @volunteer)
    sign_in_as_admin

    get oversight_path

    assert_select "h2[data-thank-you]", text: "Thank you, Vic: 1 Slot this year."
    assert_no_match(/has claimed|most Slots/i, response.body)
  end
end
