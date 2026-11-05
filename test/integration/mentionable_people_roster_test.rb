require "test_helper"

class MentionablePeopleRosterTest < ActionDispatch::IntegrationTest
  test "a non-member of an open-team Project sees only that Project's People" do
    sign_in_as(:other_volunteer)
    project = projects(:community_meal)
    project.update!(open_team: true)

    get mentionable_people_project_path(project), params: { q: "" }, as: :json

    assert_response :success
    names = response.parsed_body.fetch("people").pluck("name")
    assert_equal [ "Ada Admin", "Leo Leader", "Lucy Leader", "Vic Volunteer" ], names
  end
end
