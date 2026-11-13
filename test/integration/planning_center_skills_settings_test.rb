require "test_helper"

class PlanningCenterSkillsSettingsTest < ActionDispatch::IntegrationTest
  test "an Admin can set and clear the mapping without changing credentials or another church" do
    organization = organizations(:st_example)
    organization.update!(pco_app_id: "existing-app", pco_secret: "existing-secret")
    sign_in_as_admin
    patch planning_center_directory_path, params: { organization: { pco_skills_field_id: " 77 ", id: organizations(:outsider_church).id } }
    assert_redirected_to settings_path(anchor: "settings-directory")
    assert_equal "77", organization.reload.pco_skills_field_id
    assert_equal "existing-app", organization.pco_app_id
    assert_equal "existing-secret", organization.pco_secret
    assert_nil organizations(:outsider_church).pco_skills_field_id
    get settings_path
    assert_select "input[name='organization[pco_skills_field_id]'][value='77']"
    patch planning_center_directory_path, params: { organization: { pco_skills_field_id: "" } }
    assert_nil organization.reload.pco_skills_field_id
  end

  test "invalid mapping has an error and non-Admins cannot change it" do
    sign_in_as_admin
    patch planning_center_directory_path, params: { organization: { pco_skills_field_id: "../secrets" } }
    assert_response :unprocessable_entity
    assert_nil organizations(:st_example).reload.pco_skills_field_id
    assert_select "[role=alert]", text: /numeric Planning Center custom field ID/
    sign_in_as_volunteer
    patch planning_center_directory_path, params: { organization: { pco_skills_field_id: "77" } }
    assert_response :not_found
    assert_nil organizations(:st_example).reload.pco_skills_field_id
  end
end
