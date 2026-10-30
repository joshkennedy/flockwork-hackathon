require "test_helper"

# Pinned to the Playwright version that playwright-ruby-client 1.64.0 speaks; the gem's default would run whatever npx finds.
Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    headless: true,
    playwright_cli_executable_path: Rails.root.join("node_modules/.bin/playwright").to_s
  )
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :playwright
end
