require "test_helper"

class StaffingSuggestionsTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:st_example)
    @project = projects(:building_cleanup) # Mar 20 2027, led by other_leader
    @project.update!(skills_needed: [ "Handyman", "driving" ])
  end

  def person(name, skills)
    @organization.people.create!(name:, email: "#{name.parameterize}@st-example.test", skills:)
  end

  def suggested_names = StaffingSuggestions.new(@project).call.map { |suggestion| suggestion.person.name }

  test "skills are stored lowercase, trimmed and unique, from an array or a comma list" do
    assert_equal [ "driving", "sound and tech" ], person("Tess", [ " Driving ", "driving, Sound and Tech", "" ]).skills
  end

  test "ranks by matched skills, then lighter serving load, and shows only the matched skills" do
    person("Bo Both", %w[handyman driving cooking])
    busy = person("Ann Busy", %w[handyman])
    person("Cal Free", %w[handyman])
    person("Dee None", %w[cooking])
    projects(:community_meal).memberships.create!(person: busy, role: :volunteer)

    assert_equal [ "Bo Both", "Cal Free", "Ann Busy" ], suggested_names
    assert_equal %w[handyman driving], StaffingSuggestions.new(@project).call.first.matched_skills
    assert_equal 1, StaffingSuggestions.new(@project).call.last.serving_load
    assert_includes @organization.people.find_by(name: "Bo Both").skills, "cooking", "full tags stay on the Person"
  end

  test "rules out the Team, anyone already asked, Recipients, people without email, the away and the overextended" do
    member = person("Mia Member", %w[handyman])
    asked = person("Ash Asked", %w[handyman])
    cared_for = person("Rae Recipient", %w[handyman])
    away = person("Al Away", %w[driving])
    overextended = person("Oz Over", %w[driving])
    @organization.people.create!(name: "Nell No Email", skills: %w[handyman])
    person("Kit Keep", %w[driving])

    @project.memberships.create!(person: member, role: :volunteer)
    @project.invitations.create!(organization: @organization, person: asked, inviter: people(:other_leader), role: :volunteer)
    @project.recipients.create!(person: cared_for)
    away.unavailabilities.create!(organization: @organization, starts_on: Date.new(2027, 3, 15), ends_on: Date.new(2027, 3, 21))
    @organization.update!(overextended_limit: 1)
    overextended.memberships.create!(project: projects(:community_meal), role: :volunteer)

    assert_equal [ "Kit Keep" ], suggested_names
  end

  test "being away cannot rule anyone out while the Project has no dates" do
    away = person("Al Away", %w[driving])
    away.unavailabilities.create!(organization: @organization, starts_on: Date.new(2027, 3, 15), ends_on: Date.new(2027, 3, 21))
    @project.update!(ends_on: nil)

    assert_equal [ "Al Away" ], suggested_names
  end

  test "orders by matched skills, then serving load, then name, and caps the list at five" do
    %w[Zed Amy bob].each { |name| person(name, %w[handyman]) }
    person("Cy Both", %w[handyman driving])
    person("Di Both", %w[handyman driving])
    busy = person("Al Busy", %w[handyman])
    projects(:community_meal).memberships.create!(person: busy, role: :volunteer)
    person("Ed Late", %w[driving])

    assert_equal [ "Cy Both", "Di Both", "Amy", "Ed Late", "Zed" ], suggested_names
  end

  test "suggests no one when the Project needs no skills" do
    person("Bo Both", %w[handyman])
    @project.update!(skills_needed: [])

    assert_empty suggested_names
  end
end
