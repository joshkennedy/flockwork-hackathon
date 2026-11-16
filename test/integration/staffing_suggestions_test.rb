require "test_helper"

class StaffingSuggestionsFlowTest < ActionDispatch::IntegrationTest
  test "a volunteer lists skills, a Leader asks for them, and the Team page suggests the volunteer with only the matches" do
    sign_in_as(:other_volunteer)
    patch profile_path, params: { person: { name: "Vera Volunteer", skills: [ "", "cooking", "Driving, Juggling" ] } }
    assert_equal %w[cooking driving juggling], people(:other_volunteer).reload.skills

    sign_in_as_leader
    project = projects(:community_meal)
    get team_project_path(project)
    assert_select "#suggested-heading + p", /Add the skills this Project needs/

    patch project_path(project), params: { project: { skills_needed: [ "", "driving" ] } }
    assert_equal %w[driving], project.reload.skills_needed

    get team_project_path(project)
    assert_select "section[aria-labelledby=suggested-heading] li", text: /Vera Volunteer\s*Driving · Serving on 0 Active Projects/ do
      assert_select "input[name='invitation[person_id]'][value='#{people(:other_volunteer).id}']"
    end
    assert_select "section[aria-labelledby=suggested-heading]", text: /Juggling/, count: 0
  end

  test "a Volunteer cannot set a Project's skills or see suggestions" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    patch project_path(project), params: { project: { skills_needed: [ "driving" ] } }
    assert_empty project.reload.skills_needed
    get team_project_path(project)
    assert_select "#suggested-heading", count: 0
  end

  test "the empty suggestion state explains who availability leaves out" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(skills_needed: [ "setup and teardown" ])

    get team_project_path(project)

    assert_select "section[aria-labelledby=suggested-heading] p", text: /No one available to invite lists Setup and teardown yet\./
    assert_select "section[aria-labelledby=suggested-heading] p", text: /already connected to this Project, away during it, or at the serving limit/
    assert_no_match "No one free", response.body
  end
end
