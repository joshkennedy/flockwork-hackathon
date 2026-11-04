require "test_helper"

class ErrorPagesTest < ActionDispatch::IntegrationTest
  test "a denied URL renders the branded not-found page with production-style exception handling" do
    sign_in_as_volunteer
    env_config = Rails.application.env_config
    original_show_exceptions = env_config["action_dispatch.show_exceptions"]
    original_show_detailed_exceptions = env_config["action_dispatch.show_detailed_exceptions"]

    env_config["action_dispatch.show_exceptions"] = :all
    env_config["action_dispatch.show_detailed_exceptions"] = false

    get people_path

    assert_response :not_found
    assert_includes response.body, "Flockwork"
    assert_includes response.body, "That page isn’t available."
    assert_select "a[href='/']", text: "Back Home"
  ensure
    env_config["action_dispatch.show_exceptions"] = original_show_exceptions
    env_config["action_dispatch.show_detailed_exceptions"] = original_show_detailed_exceptions
  end
end
