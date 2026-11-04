require "application_system_test_case"

class MobileTouchTargetsSystemTest < ApplicationSystemTestCase
  TOUCH_TARGET_ALLOWLIST = {
    ".sr-only" => "The skip link is visually hidden until keyboard focus, when its padding makes it at least 44px tall.",
    "p a.link" => "Inline links in running copy stay inline so their text wraps naturally."
  }.freeze

  test "Project and Planner actions meet phone touch target guidance" do
    demo_project = build_demo_project
    sign_in_as_leader_in_browser
    page.current_window.resize_to(390, 844)

    visit project_path(demo_project)
    assert_selector "h1", text: demo_project.name
    assert_touch_targets_are_at_least_44_pixels

    find("summary[aria-label^='Actions for Welcome team']").click
    assert_touch_targets_are_at_least_44_pixels

    tab_bar = find(".project-tab-strip .tab-bar")
    assert_operator page.evaluate_script("arguments[0].scrollWidth", tab_bar), :>, page.evaluate_script("arguments[0].clientWidth", tab_bar)
    assert_selector ".project-tab-strip[data-at-end='false']"
    assert_not_equal "none", page.evaluate_script("getComputedStyle(arguments[0], '::after').backgroundImage", find(".project-tab-strip"))

    click_link "Tasks", exact: true
    assert_touch_targets_are_at_least_44_pixels
    find("summary[aria-label='Actions for Set up welcome table']").click
    assert_touch_targets_are_at_least_44_pixels

    click_link "Team", exact: true
    assert_selector ".project-tab-strip[data-at-end='true']"
    assert page.evaluate_script(<<~JS, tab_bar)
      (() => {
        const bar = arguments[0];
        const active = bar.querySelector('[aria-current="true"]');
        const barRect = bar.getBoundingClientRect();
        const activeRect = active.getBoundingClientRect();
        return activeRect.left >= barRect.left && activeRect.right <= barRect.right;
      })()
    JS

    visit new_project_path
    assert_touch_targets_are_at_least_44_pixels
  end

  private
    def build_demo_project
      project = Project.create_for(
        creator: people(:grace_leader),
        attributes: {
          name: "Mobile Ministry Demo",
          description: "Coordinate a volunteer day.",
          starts_on: Date.current + 1.day,
          ends_on: Date.current + 7.days,
          enabled_tools: Project::TOOLS
        }
      )
      project.tasks.create!(title: "Set up welcome table", due_on: Date.current + 1.day)
      project.slots.create!(label: "Welcome team", date: Date.current + 1.day, capacity: 2)
      project
    end

    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end

    def assert_touch_targets_are_at_least_44_pixels
      allowlist = TOUCH_TARGET_ALLOWLIST.keys.join(", ")
      violations = nil
      begin
        page.document.synchronize do
          violations = page.evaluate_script(<<~JS)
            (() => {
              const allowlist = #{allowlist.to_json};
              const visible = (element) => {
                const style = getComputedStyle(element);
                const rect = element.getBoundingClientRect();
                const closedDetails = element.closest('details:not([open])');
                const closedDialog = element.closest('dialog:not([open])');
                return style.visibility !== "hidden" && style.display !== "none" &&
                  (!closedDetails || element === closedDetails.querySelector(':scope > summary')) &&
                  !closedDialog && rect.width > 0 && rect.height > 0;
              };

              return [...document.querySelectorAll('a[href], button:not([disabled]), summary, input:not([type="hidden"]):not([type="checkbox"]):not([type="radio"]), select, textarea, trix-editor, [role="button"]')]
                .filter(visible)
                .filter((element) => !allowlist || !element.matches(allowlist))
                .map((element) => {
                  const rect = element.getBoundingClientRect();
                  return {
                    label: element.getAttribute('aria-label') || element.textContent.trim().replace(/\s+/g, ' ').slice(0, 80),
                    tag: element.tagName.toLowerCase(),
                    classes: element.className,
                    width: Math.round(rect.width * 10) / 10,
                    height: Math.round(rect.height * 10) / 10
                  };
                })
                .filter(({ width, height }) => width < 44 || height < 44);
            })()
          JS
          raise Capybara::ElementNotFound, "Touch targets are still animating" if violations.any?
        end
      rescue Capybara::ElementNotFound
        # Keep the final measured violations for the assertion message below.
      end

      assert_empty violations, "Touch targets below 44x44 at #{page.current_path}: #{violations.inspect}"
    end
end
