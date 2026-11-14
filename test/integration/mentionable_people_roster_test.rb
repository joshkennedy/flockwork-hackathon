require "test_helper"

class MentionablePeopleRosterTest < ActionDispatch::IntegrationTest
  test "a non-member of an open-team Project cannot read its mentionable People" do
    sign_in_as(:other_volunteer)
    project = projects(:community_meal)
    project.update!(open_team: true)

    get mentionable_people_project_path(project), params: { q: "" }, as: :json

    assert_response :not_found
  end
end
