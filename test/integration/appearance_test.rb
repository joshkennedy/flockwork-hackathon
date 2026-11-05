require "test_helper"

class AppearanceTest < ActionDispatch::IntegrationTest
  test "a dark cookie renders dark on the server with no device check" do
    sign_in_as_volunteer
    cookies[:appearance] = "dark"

    get home_path

    assert_select "html[data-dark]"
    assert_select "head script[src*=device_theme]", count: 0
  end

  test "with no choice the page follows the device setting" do
    sign_in_as_volunteer

    get home_path

    assert_select "html[data-dark]", count: 0
    assert_select "head script[src*=device_theme]"
  end

  test "an unknown cookie value falls back to following the device" do
    cookies[:appearance] = "purple"

    get root_path

    assert_select "html[data-dark]", count: 0
    assert_select "head script[src*=device_theme]"
  end

  test "the default mark color is left to the stylesheet so dark mode can brighten it" do
    sign_in_as_volunteer

    get home_path

    assert_select "body[style*='--color-mark']", count: 0
  end
end
