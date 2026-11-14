require "test_helper"
require_relative "../support/method_stubs"

class CheckInsTest < ActionDispatch::IntegrationTest
  include MethodStubs

  setup do
    @organization = organizations(:st_example)
    @volunteer = people(:volunteer)
    projects(:building_cleanup).memberships.create!(person: @volunteer, role: :volunteer)
    third = @organization.projects.create!(name: "Neighborhood Visits", owner: people(:other_leader))
    third.memberships.create!(person: @volunteer, role: :volunteer)
  end

  test "a Leader logs a check-in with an optional note, and the person drops off the list for the window" do
    sign_in_as_leader

    post person_check_ins_path(@volunteer), params: { check_in: { on: Date.current.iso8601, note: "Asked about Saturdays" } }

    assert_redirected_to oversight_path
    check_in = CheckIn.last
    assert_equal people(:leader), check_in.checked_in_by
    assert_equal "Asked about Saturdays", check_in.note
    assert_equal @organization, check_in.organization

    get oversight_path
    assert_select "[data-overextended-person='Vic Volunteer']", 0
  end

  test "a Leader cannot log a check-in for someone on none of the Projects they lead, and nothing is saved" do
    sign_in_as_leader
    stranger = people(:other_volunteer)

    post person_check_ins_path(stranger), params: { check_in: { on: Date.current.iso8601 } }

    assert_response :not_found
    assert_equal 0, CheckIn.count
  end

  test "Oversight hides check-in controls for a Person the Leader cannot check in" do
    ineligible = people(:admin)
    ineligible.update!(name: "Ineligible Admin")
    3.times do |index|
      project = @organization.projects.create!(name: "Admin Project #{index}", owner: ineligible)
      project.memberships.create!(person: ineligible, role: :leader)
    end
    sign_in_as_leader

    get oversight_path

    assert_select "[data-overextended-person='Ineligible Admin']" do
      assert_select "form[action=?]", person_check_ins_path(ineligible), count: 0
      assert_select "input[type=submit][value='Log a Check-In']", count: 0
    end
  end

  test "an Admin logs a check-in for someone on no Project" do
    sign_in_as_admin
    stranger = people(:other_volunteer)

    post person_check_ins_path(stranger), params: { check_in: { on: Date.current.iso8601 } }

    assert_redirected_to oversight_path
    assert_equal [ stranger ], CheckIn.all.map(&:person)
  end

  test "a volunteer cannot log a check-in, and nothing is saved" do
    sign_in_as_volunteer

    post person_check_ins_path(@volunteer), params: { check_in: { on: Date.current.iso8601 } }

    assert_response :not_found
    assert_equal 0, CheckIn.count
  end

  test "a check-in for someone in another Organization is not found" do
    sign_in_as_leader
    outsider = people(:grace_volunteer)

    post person_check_ins_path(outsider), params: { check_in: { on: Date.current.iso8601 } }

    assert_response :not_found
    assert_equal 0, CheckIn.count
  end

  test "a Leader sees the latest check-in in the summary, but not the Admin note" do
    CheckIn.create!(organization: @organization, person: @volunteer, checked_in_by: people(:admin), on: Date.current - 40, note: "Admin-only remark")
    sign_in_as_leader

    get oversight_path

    assert_select "[data-overextended-person='Vic Volunteer']" do
      assert_select "p", text: /last check-in #{(Date.current - 40).strftime("%b %-d")}/
    end
    assert_no_match "Admin-only remark", response.body
  end

  test "an Admin sees the note on the card" do
    CheckIn.create!(organization: @organization, person: @volunteer, checked_in_by: people(:leader), on: Date.current - 40, note: "Admin-only remark")
    sign_in_as_admin

    get oversight_path

    assert_match "Admin-only remark", response.body
  end

  test "a check-in dated in the future is refused with a message" do
    sign_in_as_admin

    post person_check_ins_path(@volunteer), params: { check_in: { on: (Date.current + 1).iso8601 } }

    assert_redirected_to oversight_path
    assert_equal "On cannot be in the future", flash[:alert]
    assert_equal 0, CheckIn.count
  end

  test "the card ignores old AI summaries and shows current facts" do
    store = ActiveSupport::Cache::MemoryStore.new
    sign_in_as_admin

    stub_method(Rails, :cache, -> { store }) do
      get oversight_path
      assert_select "p", text: /Serving on 3 Active Projects since/
      assert_match "Serving on 3 Active Projects since", response.body

      facts = OversightSummary.facts_for(@volunteer, last_check_in: nil)
      store.write("oversight-summary/#{@volunteer.id}/#{Digest::SHA256.hexdigest(facts.to_json)[0, 16]}", "Serving on 3 Active Projects, with a check-in on file.")
      get oversight_path
      assert_no_match "Serving on 3 Active Projects, with a check-in on file.", response.body
      assert_match "Serving on 3 Active Projects since", response.body
    end
  end
end
