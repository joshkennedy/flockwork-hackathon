require "test_helper"
require "webmock/minitest"

class DirectorySources::PlanningCenterSkillsTest < ActiveSupport::TestCase
  ROOT = "https://api.planningcenteronline.com/people/v2"

  test "configured organization mapping flows through the sync job into saved Skills" do
    organization = organizations(:st_example)
    organization.update!(pco_app_id: "fixture-app", pco_secret: "fixture-secret", pco_skills_field_id: "77")
    field_definition
    people_page
    fields("1", [ datum("1", "Cooking, Driving") ])

    DirectorySyncJob.perform_now(organization)

    assert_equal [ "cooking", "driving" ], organization.people.find_by!(external_id: "1").skills
    assert_equal 1, organization.reload.pco_last_sync_result.fetch("created")
    assert_nil organization.pco_last_sync_error
  end

  test "mapped text field imports normalized labels through Person and field pagination" do
    field_definition
    people_page(next_url: "#{ROOT}/people?page=2")
    stub_request(:get, "#{ROOT}/people?page=2").to_return(json(data: [ remote_person("2") ], included: []))
    fields("1", [ datum("1", " Cooking, Driving, COOKING ") ], next_url: "#{ROOT}/people/1/field_data?page=2")
    stub_request(:get, "#{ROOT}/people/1/field_data?page=2").to_return(json(data: []))
    fields("2", [ datum("2", "Teaching") ])

    rows = source.each_person.to_a
    assert_equal [ [ "cooking", "driving" ], [ "teaching" ] ], rows.pluck(:skills)
    assert_equal [ "1", "2" ], rows.pluck(:external_id)
  end

  test "missing mapping makes no field requests and preserves existing local Skills" do
    person = people(:leader)
    person.update!(skills: [ "music" ], external_source: "planning_center", external_id: "1")
    people_page
    DirectorySync.new(person.organization, source(field: nil)).call
    assert_equal [ "music" ], person.reload.skills
    assert_not_requested :get, /field_definitions|field_data/
  end

  test "missing datum preserves tags while explicit blank clears them" do
    person = people(:leader)
    person.update!(skills: [ "music" ], external_source: "planning_center", external_id: "1")
    field_definition
    people_page
    fields("1", [])
    DirectorySync.new(person.organization, source).call
    assert_equal [ "music" ], person.reload.skills
    fields("1", [ datum("1", "") ])
    DirectorySync.new(person.organization, source).call
    assert_empty person.reload.skills
  end

  test "unsupported field types and numeric labels fail without changing people" do
    person = people(:leader)
    person.update!(skills: [ "music" ], external_source: "planning_center", external_id: "1")
    field_definition(type: "select")
    error = assert_raises(DirectorySources::Error) { DirectorySync.new(person.organization, source).call }
    assert_includes error.message, "plain text"
    assert_equal [ "music" ], person.reload.skills
    field_definition
    people_page
    fields("1", [ datum("1", "12345") ])
    error = assert_raises(DirectorySources::Error) { DirectorySync.new(person.organization, source).call }
    assert_includes error.message, "not numeric option IDs"
    assert_equal [ "music" ], person.reload.skills
  end

  test "later provider errors roll back imported rows and never follow unsafe pagination" do
    organization = organizations(:st_example)
    field_definition
    people_page(next_url: "https://attacker.example/steal")
    fields("1", [ datum("1", "cooking") ])
    assert_no_difference -> { organization.people.count } do
      assert_raises(DirectorySources::Error) { DirectorySync.new(organization, source).call }
    end
    assert_not_requested :get, /attacker.example/
  end

  test "sync remains scoped to the target church" do
    elsewhere = people(:outsider)
    elsewhere.update!(skills: [ "music" ], external_source: "planning_center", external_id: "1")
    field_definition
    people_page
    fields("1", [ datum("1", "cooking") ])
    DirectorySync.new(organizations(:st_example), source).call
    assert_equal [ "music" ], elsewhere.reload.skills
    assert_equal [ "cooking" ], organizations(:st_example).people.find_by!(external_id: "1").skills
  end

  private
    def source(field: "77")
      DirectorySources::PlanningCenter.new(app_id: "fixture-app", secret: "fixture-secret", skills_field_id: field)
    end

    def json(payload)
      { status: 200, body: JSON.generate(payload), headers: { "Content-Type" => "application/json" } }
    end

    def field_definition(type: "string")
      stub_request(:get, "#{ROOT}/field_definitions/77").to_return(json(data: { type: "FieldDefinition", id: "77", attributes: { data_type: type } }))
    end

    def remote_person(id)
      { type: "Person", id: id, attributes: { name: "Mapped Helper #{id}" }, relationships: {} }
    end

    def people_page(next_url: nil)
      stub_request(:get, DirectorySources::PlanningCenter::PEOPLE_URL).to_return(json(data: [ remote_person("1") ], included: [], links: { next: next_url }))
    end

    def datum(id, value)
      { type: "FieldDatum", id: id, attributes: { value: value }, relationships: { field_definition: { data: { id: "77", type: "FieldDefinition" } } } }
    end

    def fields(person_id, data, next_url: nil)
      stub_request(:get, "#{ROOT}/people/#{person_id}/field_data").with(query: { "where[field_definition_id]" => "77", "per_page" => "100" })
        .to_return(json(data: data, links: { next: next_url }))
    end
end
