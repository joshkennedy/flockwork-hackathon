require "test_helper"

class SearchTest < ActionDispatch::IntegrationTest
  test "search limits Projects to visible records in the current church" do
    person = sign_in_as_volunteer
    visible = Project.create_for(creator: person, attributes: { name: "Unique search visible" })
    hidden = Project.create_for(creator: people(:admin), attributes: { name: "Unique search hidden" })
    other = Project.create_for(creator: people(:outsider), attributes: { name: "Unique search other" })
    get search_path, params: { query: "Unique search" }
    assert_select "a[href=?]", project_path(visible)
    assert_select "a[href=?]", project_path(hidden), count: 0
    assert_select "a[href=?]", project_path(other), count: 0
    get search_path, params: { query: "Unique search", project_id: hidden.id }
    assert_response :not_found
  end

  test "only Admins and Leaders can find people names without exposing emails" do
    person = people(:volunteer)
    sign_in_as_admin
    get search_path, params: { query: person.name }
    assert_select "section[aria-label=People] a[href=?] .font-medium", person_path(person), text: person.name
    assert_no_match person.email, response.body if person.email.present?
    sign_in_as_leader
    get search_path, params: { query: person.name }
    assert_select "section[aria-label=People] a[href=?] .font-medium", search_person_path(person), text: person.name
    sign_in_as_volunteer
    get search_path, params: { query: person.name }
    assert_select "section[aria-label=People]", count: 0
  end

  test "work is searchable across visible Projects but hidden and disabled Tools do not leak" do
    person = sign_in_as_leader
    project = Project.create_for(creator: person, attributes: { name: "Current search", enabled_tools: [ "tasks", "signup_sheet", "schedule", "docs" ] })
    project.tasks.create!(title: "Searchable task")
    project.slots.create!(label: "Searchable slot", date: Date.current)
    project.schedule_items.create!(title: "Searchable gathering", date: Date.current)
    project.doc_items.create!(title: "Searchable handbook", kind: :link, url: "https://example.org", author: person)
    [ people(:admin), people(:outsider) ].each do |owner|
      hidden = Project.create_for(creator: owner, attributes: { name: "Searchable hidden", enabled_tools: [ "tasks", "signup_sheet", "schedule", "docs" ] })
      hidden.tasks.create!(title: "Searchable secret task")
      hidden.slots.create!(label: "Searchable secret slot", date: Date.current)
      hidden.schedule_items.create!(title: "Searchable secret gathering", date: Date.current)
      hidden.doc_items.create!(title: "Searchable secret handbook", kind: :link, url: "https://example.org", author: owner)
    end
    get search_path, params: { query: "Searchable", project_id: project.id }
    assert_select "section[aria-label=Tasks]", text: /Searchable task/
    assert_select "section[aria-label=Slots]", text: /Searchable slot/
    get search_path, params: { query: "Searchable" }
    assert_select "section[aria-label=Tasks]", text: /Searchable task/
    assert_select "section[aria-label=Slots]", text: /Searchable slot/
    assert_select "section[aria-label=Schedule]", text: /Searchable gathering/
    assert_select "section[aria-label='Docs & Files']", text: /Searchable handbook/
    assert_no_match "Searchable secret", response.body
    project.update!(enabled_tools: [])
    get search_path, params: { query: "Searchable", project_id: project.id }
    assert_select "section[aria-label=Tasks], section[aria-label=Slots], section[aria-label=Schedule], section[aria-label='Docs & Files']", count: 0
  end

  test "live results tolerate typos, match words out of order, rank exact matches first and safely highlight" do
    person = sign_in_as_admin
    project = Project.create_for(creator: person, attributes: { name: "Christmas welcome" })
    Project.create_for(creator: person, attributes: { name: "Christmas welcoming" })
    get search_path, params: { query: "welcome christms" }, headers: { "Turbo-Frame" => "search-results" }
    assert_response :success
    assert_select "#search-results section[aria-label=Projects] a" do |links|
      assert_equal project_path(project), links.first["href"]
    end
    assert_select "mark", text: "Christmas"
    assert_select "mark", text: "welcome"
    assert_select "dialog", count: 0
    project.update!(name: "Family meals")
    get search_path, params: { query: "famly meel" }, headers: { "Turbo-Frame" => "search-results" }
    assert_select "section[aria-label=Projects] a[href=?]", project_path(project)
    assert_select "mark", text: "Family"
    get search_path, params: { query: '<script>alert("x")</script>' }, headers: { "Turbo-Frame" => "search-results" }
    assert_select "script", count: 0
    assert_includes response.body, "&lt;script&gt;"
  end

  test "LIKE wildcards are literal and each result group is bounded" do
    person = sign_in_as_admin
    10.times { |index| Project.create_for(creator: person, attributes: { name: "Bounded search #{index}" }) }
    get search_path, params: { query: "Bounded search" }
    assert_select "section[aria-label=Projects] li", count: 8
    get search_path, params: { query: "%" }
    assert_select "section[aria-label=Projects]", count: 0
    get search_path, params: { query: " " }
    assert_select "#search-page-results a", text: /Home/
    get search_path, params: { query: "peple" }
    assert_select "section[aria-label=Pages] a[href=?]", people_path
    sign_in_as_volunteer
    get search_path, params: { query: "peple" }
    assert_select "section[aria-label=Pages] a[href=?]", people_path, count: 0
  end

  test "Leader person results show only shared visible Projects without contact or private history" do
    viewer = sign_in_as_leader
    target = people(:volunteer)
    visible = Project.create_for(creator: viewer, attributes: { name: "Shared visible search Project" })
    visible.memberships.create!(person: target, role: :volunteer)
    hidden = Project.create_for(creator: people(:admin), attributes: { name: "Private search sentinel" })
    hidden.memberships.create!(person: target, role: :volunteer)
    target.update!(phone: "+12025550123")
    get search_person_path(target)
    assert_response :success
    assert_select "h1", text: target.name
    assert_select "a[href=?]", project_path(visible), text: visible.name
    assert_no_match hidden.name, response.body
    assert_no_match target.email, response.body
    assert_no_match target.phone, response.body
    assert_select "a[href=?]", edit_person_path(target), count: 0

    get search_person_path(people(:outsider))
    assert_response :not_found
    sign_in_as_volunteer
    get search_person_path(target)
    assert_response :not_found
  end

  test "person result with no shared visible Projects has a safe empty state" do
    viewer = sign_in_as_leader
    target = viewer.organization.people.create!(name: "Unassigned Search Helper")
    get search_person_path(target)
    assert_response :success
    assert_select "h1", text: target.name
    assert_select "p", text: "No shared Projects are available to view."
  end
end
