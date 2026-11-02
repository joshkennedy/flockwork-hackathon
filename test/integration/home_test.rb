require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "Home shows your week and the open spots this week" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    mine = project.slots.create!(date: Date.current + 1, label: "Bring salad", capacity: 2)
    mine.slot_claims.create!(person: leader)
    project.slots.create!(date: Date.current + 2, label: "Bring dessert", capacity: 3)
    project.slots.create!(date: Date.current + 30, label: "Far off", capacity: 1)
    full = project.slots.create!(date: Date.current + 3, label: "Full bread", capacity: 1)
    full.slot_claims.create!(person: leader)

    get home_path

    assert_select "[data-home-section='your-week']", text: /Bring salad/
    assert_select "[data-home-section='open-needs']", text: /Community Meal/
    # Bring salad has 1 open spot, Bring dessert 3; Full bread and Far off add none.
    assert_select "[data-home-section='open-needs'] .badge-need", text: "4 spots open"
    assert_select "[data-home-section='open-needs']", text: /Next: Bring salad/
    assert_no_match "Far off", response.body
  end

  test "Home points a person with no Projects somewhere useful" do
    organization = Organization.create!(name: "New Church")
    sign_in_as organization.people.create!(name: "Nina New", email: "nina@new.example", admin: true)
    get home_path

    assert_select "[data-home-section]", count: 0
    assert_select "a.btn-primary", count: 1
  end
end
