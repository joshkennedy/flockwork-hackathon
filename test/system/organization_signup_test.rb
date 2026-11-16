require "application_system_test_case"

class OrganizationSignupSystemTest < ApplicationSystemTestCase
  test "sign-up preselects the browser time zone" do
    page.driver.with_playwright_page do |browser|
      browser.context.add_init_script(script: <<~JS)
        const resolvedOptions = Intl.DateTimeFormat.prototype.resolvedOptions
        Intl.DateTimeFormat.prototype.resolvedOptions = function() {
          return { ...resolvedOptions.call(this), timeZone: "America/New_York" }
        }
      JS
    end

    visit sign_up_path

    assert_field "Church time zone", with: "America/New_York"
  end
end
