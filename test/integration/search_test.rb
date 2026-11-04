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
    assert_select "section[aria-label=People] a[href=?]", person_path(person), text: person.name
    assert_no_match person.email, response.body if person.email.present?
    sign_in_as_leader
    get search_path, params: { query: person.name }
    assert_select "section[aria-label=People] a[href=?]", search_person_path(person), text: person.name
    sign_in_as_volunteer
    get search_path, params: { query: person.name }
    assert_select "section[aria-label=People]", count: 0
  end

  test "current Project work is scoped and disabled Tools do not leak results" do
    person = sign_in_as_leader
    project = Project.create_for(creator: person, attributes: { name: "Current search", enabled_tools: [ "tasks", "signup_sheet" ] })
    project.tasks.create!(title: "Searchable task")
    project.slots.create!(label: "Searchable slot", date: Date.current)
    get search_path, params: { query: "Searchable", project_id: project.id }
    assert_select "section[aria-label=Tasks]", text: /Searchable task/
    assert_select "section[aria-label=Slots]", text: /Searchable slot/
    get search_path, params: { query: "Searchable" }
    assert_select "section[aria-label=Tasks]", count: 0
    project.update!(enabled_tools: [])
    get search_path, params: { query: "Searchable", project_id: project.id }
    assert_select "section[aria-label=Tasks], section[aria-label=Slots]", count: 0
  end

  test "LIKE wildcards are literal and each result group is bounded" do
    person = sign_in_as_admin
    10.times { |index| Project.create_for(creator: person, attributes: { name: "Bounded search #{index}" }) }
    get search_path, params: { query: "Bounded search" }
    assert_select "section[aria-label=Projects] li", count: 8
    get search_path, params: { query: "%" }
    assert_select "section[aria-label=Projects]", count: 0
    get search_path, params: { query: " " }
    assert_select "#search-page-results", text: /Enter a name/
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
