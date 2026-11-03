require "test_helper"

class GetInvolvedTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @project.update!(open_team: true, enabled_tools: @project.enabled_tools + [ "signup_sheet" ])
  end

  test "Get involved leads with open Slots grouped by when, with who is going and spots left" do
    this_week = @project.slots.create!(date: Date.current, label: "Dinner", capacity: 4)
    @project.slots.create!(date: Date.current.next_week + 1, label: "Setup", capacity: 2)
    @project.slots.create!(date: Date.current.next_week.end_of_week + 1, label: "Cleanup", capacity: 1)
    this_week.claim(people(:leader))
    this_week.claim(people(:other_leader))
    this_week.claim(people(:admin))
    sign_in_as_volunteer

    get get_involved_path

    assert_response :success
    assert_select "section[aria-labelledby='needs-heading'] h3", text: "This week"
    assert_select "section[aria-labelledby='needs-heading'] h3", text: "Next week"
    assert_select "section[aria-labelledby='needs-heading'] h3", text: "Later"
    assert_select "section[aria-labelledby='needs-heading'] li", text: /Community Meal.*Dinner.*and 2 others signed up/m
    assert_select "section[aria-labelledby='needs-heading'] li", text: /1 spot left/
    assert_select "section[aria-labelledby='joined-teams-heading'] li", text: /3 of 7 spots filled/
  end

  test "a Volunteer claims an open Slot from Get involved and lands back there" do
    slot = @project.slots.create!(date: Date.current + 1, label: "Dinner", capacity: 1)
    later_slot = @project.slots.create!(date: Date.current + 2, label: "Dinner", capacity: 2)
    volunteer = sign_in_as_volunteer

    get get_involved_path
    assert_select "form[action=?]", project_slot_claim_path(@project, slot), count: 1

    post project_slot_claim_path(@project, slot), params: { from: "get_involved" }
    assert_redirected_to get_involved_path
    assert_includes slot.reload.people, volunteer

    get get_involved_path
    assert_select "section[aria-labelledby='needs-heading'] li", text: /You’re bringing dinner/
    assert_select "form[action=?]", project_slot_claim_path(@project, slot), count: 0
    assert_select "section[aria-labelledby='needs-heading'] li", text: /1 spot left/, count: 0

    post project_slot_claim_path(@project, later_slot)
    assert_redirected_to project_path(@project)
  end

  test "a Volunteer who is not on the Team sees Join, not a claim button, and joins from Get involved" do
    project = projects(:building_cleanup)
    project.update!(open_team: true, enabled_tools: [ "signup_sheet" ])
    slot = project.slots.create!(date: Date.current + 1, label: "Setup", capacity: 2)
    sign_in_as_volunteer

    get get_involved_path

    assert_select "section[aria-labelledby='needs-heading']", text: /Join the Team to sign up/
    assert_select "form[action=?]", project_slot_claim_path(project, slot), count: 0
    assert_select "section[aria-labelledby='open-teams-heading'] form[action=?]", join_project_path(project)

    post join_project_path(project), params: { from: "get_involved" }
    assert_redirected_to get_involved_path

    get get_involved_path
    assert_select "form[action=?]", project_slot_claim_path(project, slot), count: 1
  end

  test "Get involved says so warmly when no Team is open" do
    Project.update_all(open_team: false)
    sign_in_as_volunteer

    get get_involved_path

    assert_select "p", text: "No open Teams right now."
    assert_select "p", text: /When a Team opens its doors/
  end

  test "Get involved says every spot is covered when nothing is open" do
    slot = @project.slots.create!(date: Date.current + 1, label: "Dinner", capacity: 1)
    slot.claim(people(:other_leader))
    sign_in_as_volunteer

    get get_involved_path

    assert_select "section[aria-labelledby='needs-heading'] p", text: /Every spot is covered for now/
    assert_select "section[aria-labelledby='joined-teams-heading'] li", text: /1 of 1 dinner filled · all covered/
  end
end
