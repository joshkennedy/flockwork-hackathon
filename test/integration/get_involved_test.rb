require "test_helper"

class GetInvolvedTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @project.update!(open_team: true, enabled_tools: @project.enabled_tools + [ "signup_sheet" ])
  end

  test "Get involved leads with a Needs a hand card of the Projects short on people" do
    this_week = @project.slots.create!(date: Date.current, label: "Dinner", capacity: 4)
    @project.slots.create!(date: Date.current.next_week + 1, label: "Setup", capacity: 2)
    @project.slots.create!(date: Date.current.next_week.end_of_week + 1, label: "Cleanup", capacity: 1)
    this_week.claim(people(:leader))
    this_week.claim(people(:other_leader))
    this_week.claim(people(:admin))
    sign_in_as_volunteer

    get get_involved_path

    assert_response :success
    assert_select "section[aria-labelledby='needs-heading'] h2", text: "Open Sign-up spots"
    assert_select "section[aria-labelledby='needs-heading'] a[href=?]", project_path(@project), text: /Community Meal.*4 spots still open/m
    assert_select "section[aria-labelledby='needs-heading'] .status-chip", text: "This week"
    assert_select "section[aria-labelledby='joined-teams-heading'] li", text: /3 of 7 spots filled/
  end

  test "Needs a hand sends a Volunteer through to the Project to sign up" do
    slot = @project.slots.create!(date: Date.current + 1, label: "Dinner", capacity: 1)
    volunteer = sign_in_as_volunteer

    get get_involved_path
    assert_select "section[aria-labelledby='needs-heading'] a[href=?]", project_path(@project)
    assert_select "form[action=?]", project_slot_claim_path(@project, slot), count: 0

    get project_path(@project)
    assert_select "form[action=?]", project_slot_claim_path(@project, slot)

    post project_slot_claim_path(@project, slot)
    assert_includes slot.reload.people, volunteer

    get get_involved_path
    assert_select "section[aria-labelledby='needs-heading'] p", text: /No open Sign-up spots right now/
  end

  test "a Volunteer who is not on the Team can browse open spots without joining first" do
    project = projects(:building_cleanup)
    project.update!(open_team: true, enabled_tools: [ "signup_sheet" ])
    project.slots.create!(date: Date.current + 1, label: "Setup", capacity: 2)
    sign_in_as(:other_volunteer)

    get get_involved_path

    assert_select "section[aria-labelledby='needs-heading'] a[href=?]", project_path(project), text: /2 spots still open · next/
    assert_select "section[aria-labelledby='open-teams-heading'] a.btn[href=?]", project_path(project), text: "View Open Spots"
    assert_select "section[aria-labelledby='open-teams-heading'] form[action=?]", join_project_path(project), count: 0
  end

  test "Project card images link through to the Project" do
    attach_ready_banner(@project)
    @project.reload.banner_ready?
    sign_in_as(:other_volunteer)

    get get_involved_path

    assert_select "section[aria-labelledby='open-teams-heading'] a[href=?] img", project_path(@project), minimum: 1
  end

  test "Get involved says so warmly when no Team is open" do
    Project.update_all(open_team: false)
    sign_in_as_volunteer

    get get_involved_path

    assert_select "p", text: "No open Teams right now."
    assert_select "p", text: /When a Team opens its doors/
  end

  test "Get involved names open Sign-up spots separately from unassigned Tasks" do
    slot = @project.slots.create!(date: Date.current + 1, label: "Dinner", capacity: 1)
    slot.claim(people(:other_leader))
    project_with_task = projects(:building_cleanup)
    project_with_task.update!(open_team: true, enabled_tools: [ "tasks" ])
    project_with_task.tasks.create!(title: "Pack supplies")
    sign_in_as_volunteer

    get get_involved_path

    assert_select "section[aria-labelledby='needs-heading'] p", text: "No open Sign-up spots right now. Projects with unassigned Tasks are listed below."
    assert_select "section[aria-labelledby='open-teams-heading'] .badge-need", text: "1 unassigned Task"
    assert_select "section[aria-labelledby='joined-teams-heading'] li", text: /1 of 1 dinner filled · all covered/
  end
end
