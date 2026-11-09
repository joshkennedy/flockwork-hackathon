require "test_helper"
require_relative "../support/method_stubs"

class ProfileAwayDatesTest < ActionDispatch::IntegrationTest
  include MethodStubs

  setup do
    @volunteer = sign_in_as_volunteer
    @draft_ranges = [ { starts_on: Date.new(2026, 7, 1), ends_on: Date.new(2026, 7, 31) } ]
  end

  test "AI text proposes dates on Profile and saves nothing until the person confirms" do
    stub_method(AwayDateParser, :call, ->(*) { @draft_ranges }) do
      post suggest_away_profile_path, params: { away_text: "Out most of July" }
    end

    assert_response :success
    assert_select ".ghost", text: /Suggested · not saved yet/
    assert_select "input[name='unavailabilities[][starts_on]'][value='2026-07-01']"
    assert_equal 0, @volunteer.unavailabilities.count

    post profile_unavailabilities_path, params: { unavailabilities: [ { starts_on: "2026-07-01", ends_on: "2026-07-31", note: "Family trip" } ] }

    assert_redirected_to edit_profile_path
    assert_equal 1, @volunteer.unavailabilities.count
    assert_equal "Family trip", @volunteer.unavailabilities.first.note
  end

  test "when the AI fails the page still works and the manual fields save dates" do
    stub_method(AwayDateParser, :call, ->(*) { raise AwayDateParser::Unavailable, "timeout" }) do
      post suggest_away_profile_path, params: { away_text: "Away in March" }
    end

    assert_response :success
    assert_select "[role='alert']", text: /Couldn't turn that into dates/
    assert_select "input[name='unavailabilities[][starts_on]']"

    post profile_unavailabilities_path, params: { unavailabilities: [ { starts_on: "2026-03-01", ends_on: "2026-03-14", note: "" } ] }

    assert_equal 1, @volunteer.unavailabilities.count
  end

  test "a range that ends before it starts is refused and saves nothing" do
    post profile_unavailabilities_path, params: { unavailabilities: [ { starts_on: "2026-03-14", ends_on: "2026-03-01" } ] }

    assert_redirected_to edit_profile_path
    assert_equal "Ends on must be on or after the start date", flash[:alert]
    assert_equal 0, @volunteer.unavailabilities.count
  end

  test "an empty AI box asks for words and never calls the model" do
    stub_method(AwayDateParser, :call, ->(*) { flunk "no model call for blank text" }) do
      post suggest_away_profile_path, params: { away_text: "  " }
    end

    assert_response :success
    assert_select "[role='alert']", text: /Say when you're away/
  end

  test "a person can remove their own away dates but not someone else's" do
    own = @volunteer.unavailabilities.create!(organization: @volunteer.organization, starts_on: Date.current + 5, ends_on: Date.current + 9)
    other = people(:leader).unavailabilities.create!(organization: @volunteer.organization, starts_on: Date.current + 5, ends_on: Date.current + 9)

    delete profile_unavailability_path(other)
    assert_response :not_found
    assert Unavailability.exists?(other.id)

    delete profile_unavailability_path(own)
    assert_redirected_to edit_profile_path
    assert_not Unavailability.exists?(own.id)

    # Regression: the Profile page never rendered flash, so this notice was lost. The layout toast shows it.
    follow_redirect!
    assert_select "#flash [data-toast-entry][data-toast-kind=notice]", text: "Removed away dates."
  end
end
