require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "derives a URL-safe slug from the name" do
    organization = Organization.create!(name: "  Hope Church, Springfield ")

    assert_equal "hope-church-springfield", organization.slug
  end

  test "keeps slugs unique when the derived slug is taken" do
    organization = Organization.create!(name: "St. Example")

    assert_not_equal "st-example", organization.slug
    assert_match(/\Ast-example-[0-9a-f]{6}\z/, organization.slug)
  end

  test "never derives a slug that would shadow a top-level route" do
    organization = Organization.create!(name: "Up")

    assert_not_equal "up", organization.slug
  end

  test "requires a name" do
    assert_not Organization.new(name: " ").valid?
  end
end
