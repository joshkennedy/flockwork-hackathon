require "application_system_test_case"

class SearchSystemTest < ApplicationSystemTestCase
  test "keyboard search finds current work and closes when a result is selected" do
    project = Project.create_for(creator: people(:grace_leader), attributes: { name: "Search keyboard project", enabled_tools: [ "signup_sheet", "tasks" ] })
    project.tasks.create!(title: "Prepare search keyboard welcome")
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(project, anchor: "tab-signup_sheet")
    assert_selector "#tab-signup_sheet", visible: true
    find("body").send_keys([ :control, "k" ])
    within("dialog[open][aria-labelledby=search-heading]") do
      fill_in "Search Flockwork", with: "search keybord welcome"
      assert_link "Prepare search keyboard welcome"
    end
    project.update!(name: "Refreshed search project")
    page.execute_script("Turbo.session.refresh(window.location.href)")
    assert_selector "h1", text: "Refreshed search project"
    within("dialog[open][aria-labelledby=search-heading]") do
      assert_field "Search Flockwork", with: "search keybord welcome"
      page.driver.with_playwright_page do |browser|
        browser.keyboard.press("ArrowDown")
        browser.keyboard.press("Enter")
      end
    end
    assert_no_selector "dialog[open][aria-labelledby=search-heading]"
    assert_selector "#tab-tasks", visible: true
    find("a[aria-label='Search Flockwork']").click
    assert_selector "dialog[open][aria-labelledby=search-heading]"
    find("#global_search_query").send_keys(:escape)
    assert_no_selector "dialog[open][aria-labelledby=search-heading]"
    assert_equal "Search Flockwork", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
  end

  test "a Leader can open a specific person from search without directory access" do
    viewer = people(:grace_leader)
    target = people(:grace_volunteer)
    project = Project.create_for(creator: viewer, attributes: { name: "Shared person search Project", enabled_tools: [] })
    project.memberships.create!(person: target, role: :volunteer)
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: viewer.name
    visit home_path
    find("body").send_keys([ :control, "k" ])
    within("dialog[open][aria-labelledby=search-heading]") do
      fill_in "Search Flockwork", with: target.name
      click_on target.name
    end
    assert_current_path search_person_path(target)
    assert_selector "h1", text: target.name
    click_on project.name
    assert_current_path project_path(project)
  end
end
