require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "a Volunteer's Home shows their week, open spots on their Projects, and open Teams" do
    volunteer = sign_in_as_volunteer
    project = projects(:community_meal)
    mine = project.slots.create!(date: Date.current + 1, label: "Bring salad", capacity: 2)
    mine.slot_claims.create!(person: volunteer)
    project.slots.create!(date: Date.current + 2, label: "Bring dessert", capacity: 3)
    project.slots.create!(date: Date.current + 30, label: "Far off", capacity: 1)
    full = project.slots.create!(date: Date.current + 3, label: "Full bread", capacity: 1)
    full.slot_claims.create!(person: volunteer)
    projects(:building_cleanup).update!(open_team: true)

    get home_path

    assert_select "h1", "Hi Vic"
    assert_select "[data-home-section='coming-up']", text: /Bring salad/
    assert_select "[data-home-section='open-needs']", text: /Community Meal/
    # Bring salad has 1 open spot, Bring dessert 3; Full bread and Far off add none.
    assert_select "[data-home-section='open-needs'] .badge-need", text: "4 spots open"
    assert_select "[data-home-section='open-needs']", text: /Next: Bring salad/
    assert_select "[data-home-section='get-involved']", text: /#{projects(:building_cleanup).name}/
    assert_select "a.btn-primary", count: 0
    assert_no_match "Far off", response.body
  end

  test "a Leader's Home lists the Projects they lead with what each needs" do
    sign_in_as_leader
    projects(:community_meal).update!(enabled_tools: %w[signup_sheet])
    projects(:community_meal).slots.create!(date: Date.current + 2, label: "Dinner", capacity: 1)

    get home_path

    assert_select "[data-home-section='your-projects'] li", count: 1
    assert_select "[data-home-section='your-projects'] .badge-need", text: "1 dinner still needs someone"
    assert_select "[data-home-section='your-projects'] a", text: "Fill Spots"
    assert_select "[data-home-section='coming-up']"
    assert_select "a.btn-primary", text: "Start a Project"
  end

  test "an Admin's Home covers every active Project, neediest first" do
    sign_in_as_admin
    projects(:building_cleanup).update!(enabled_tools: %w[signup_sheet])
    projects(:building_cleanup).slots.create!(date: Date.current + 1, label: "Sweep", capacity: 2)

    get home_path

    assert_select ".status-strip dd", text: "2"
    names = css_select("[data-home-section='needs-attention'] li").map(&:text)
    assert_match projects(:building_cleanup).name, names.first
    assert_match projects(:community_meal).name, names.join
  end

  test "an empty task list says so and still shows the Projects a volunteer is on" do
    sign_in_as_volunteer
    projects(:community_meal).slots.create!(date: Date.current + 1, label: "Bring rolls", capacity: 2)

    get home_path

    assert_select "[data-home-section='your-tasks']", text: /Nothing on your plate/
    assert_select "[data-home-section='your-projects'] a", text: /#{projects(:community_meal).name}/
    assert_select "[data-home-section='open-needs'] .badge-need", text: "2 spots open"
  end

  test "the old My Tasks page redirects to Home" do
    sign_in_as_volunteer

    get "/my_tasks"

    assert_response :moved_permanently
    assert_redirected_to home_path
  end

  test "Home points a person with no Projects somewhere useful" do
    organization = Organization.create!(name: "New Church")
    sign_in_as organization.people.create!(name: "Nina New", email: "nina@new.example", admin: true)
    get home_path

    assert_select "[data-home-section]", count: 0
    assert_select "a.btn-primary", count: 1
  end
end
