require "application_system_test_case"

class SignupSlotLayoutSystemTest < ApplicationSystemTestCase
  test "assignee names stay inside a Slot card on a phone" do
    leader = people(:grace_leader)
    project = Project.create_for(
      creator: leader,
      attributes: { name: "Phone Sign-up", enabled_tools: [ "signup_sheet" ] }
    )
    slot = project.slots.create!(date: Date.current, starts_at_time: "08:30", label: "Welcome doors", capacity: 4)
    [ "Chloe Martin", "Noah Alexander Davis", "Priya Shah" ].each_with_index do |name, index|
      person = project.organization.people.create!(name:, email: "phone-helper-#{index}@example.test")
      slot.slot_claims.create!(person:)
    end

    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    page.current_window.resize_to(390, 844)
    visit project_path(project)

    row = find("li##{dom_id(slot)}")
    names = row.find(".signup-people")
    pill = names.find(".person-pill")
    details = row.find(".signup-details > p", text: "Welcome doors · 8:30 AM")
    row_widths = row.evaluate_script("({ client: this.clientWidth, scroll: this.scrollWidth })")
    names_widths = names.evaluate_script("({ client: this.clientWidth, scroll: this.scrollWidth })")
    pill_widths = pill.evaluate_script("({ client: this.clientWidth, scroll: this.scrollWidth })")
    details_size = details.evaluate_script("({ client: this.clientWidth, scroll: this.scrollWidth, height: this.getBoundingClientRect().height, lineHeight: parseFloat(getComputedStyle(this).lineHeight) })")

    assert_operator row_widths.fetch("scroll"), :<=, row_widths.fetch("client")
    assert_operator names_widths.fetch("scroll"), :<=, names_widths.fetch("client")
    assert_operator pill_widths.fetch("client"), :<=, names_widths.fetch("client")
    assert_operator details_size.fetch("scroll"), :<=, details_size.fetch("client")
    assert_operator details_size.fetch("height"), :<=, details_size.fetch("lineHeight") * 1.25
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
      page.evaluate_script("document.documentElement.clientWidth")
  end
end
