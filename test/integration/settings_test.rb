require "test_helper"

class SettingsTest < ActionDispatch::IntegrationTest
  test "Admin picks a preset mark color and every page carries it" do
    sign_in_as_admin

    patch settings_path, params: { organization: { mark_color_choice: Organization::MARK_PRESETS.fetch("Clay") } }

    assert_redirected_to settings_path
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

  test "only Admins reach Settings" do
    sign_in_as_leader

    get settings_path
    assert_response :not_found
    patch settings_path, params: { organization: { mark_color_choice: "#C8502A" } }
    assert_response :not_found
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
