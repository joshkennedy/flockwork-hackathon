require "test_helper"

class SettingsTest < ActionDispatch::IntegrationTest
  test "Admin picks a preset mark color and every page carries it" do
    sign_in_as_admin

    patch settings_path, params: { organization: { mark_color_choice: Organization::MARK_PRESETS.fetch("Clay") } }

    assert_redirected_to settings_path(anchor: "settings-church")
    assert_equal "#C8502A", organizations(:st_example).reload.mark_color
    get home_path
    assert_select "body[style*='--color-mark: #C8502A']"
    assert_select "link[rel=icon][href='/icon.svg?c=C8502A']"
  end

  test "Admin saves a custom hex, normalized to uppercase with a hash" do
    sign_in_as_admin

    patch settings_path, params: { organization: { mark_color_choice: "custom", custom_mark_color: "#1a2b3c" } }

    assert_equal "#1A2B3C", organizations(:st_example).reload.mark_color
  end

  test "a malformed color is rejected and the saved color is kept" do
    sign_in_as_admin

    patch settings_path, params: { organization: { mark_color_choice: "custom", custom_mark_color: "teal" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /hex color/
    assert_equal Organization::DEFAULT_MARK_COLOR, organizations(:st_example).reload.mark_color
  end

  test "Admin renames the church and the name shows across the app" do
    sign_in_as_admin

    patch settings_path, params: { organization: { name: "St. Example Parish", overextended_limit: 4 } }

    assert_redirected_to settings_path(anchor: "settings-church")
    assert_equal [ "St. Example Parish", 4 ], organizations(:st_example).reload.values_at(:name, :overextended_limit)
    get home_path
    assert_select "[data-organization-name]", "St. Example Parish"
  end

  test "Admin sets the church time zone used by calendars" do
    sign_in_as_admin

    patch settings_path, params: { organization: { time_zone: "America/New_York" } }

    assert_redirected_to settings_path(anchor: "settings-church")
    assert_equal "America/New_York", organizations(:st_example).reload.time_zone
    get settings_path(anchor: "settings-church")
    assert_select "select[name='organization[time_zone]'] option[value='America/New_York'][selected]"
  end

  test "a blank church name re-renders the Church tab with the error" do
    sign_in_as_admin

    patch settings_path, params: { organization: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "#settings-church:not([hidden]) [role=alert]", text: /Name can't be blank/
    assert_select "#settings-details[hidden]"
  end

  test "everyone has Settings for themselves, but only Admins see and change the church's" do
    sign_in_as_leader

    get settings_path
    assert_response :success
    assert_select "#settings-details"
    assert_select "#settings-church", count: 0
    assert_select "#settings-directory", count: 0

    patch settings_path, params: { organization: { mark_color_choice: "#C8502A", name: "Taken over" } }
    assert_response :not_found
    assert_equal "St. Example", organizations(:st_example).reload.name
  end

  test "old Profile, weekly email and Planning Center links land on their Settings tab" do
    sign_in_as_admin

    get "/profile/edit"
    assert_redirected_to "/settings#settings-notifications"
    get digest_preferences_path
    assert_redirected_to "/settings#settings-notifications"
    get planning_center_directory_path
    assert_redirected_to "/settings#settings-directory"
  end

  test "the favicon draws the requested color and falls back to the default" do
    get icon_path(c: "C8502A")
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.body, 'stroke="#C8502A"'
    assert_not_includes response.body, ".lead { stroke: #F5B000 }"

    get icon_path(c: "nope")
    assert_includes response.body, %(stroke="#{Organization::DEFAULT_MARK_COLOR}")
    assert_includes response.body, ".lead { stroke: #F5B000 }"
  end
end
