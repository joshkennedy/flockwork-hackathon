require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "derives a URL-safe slug from the name" do
    workspace = Workspace.create!(name: "  Hope Church, Springfield ")

    assert_equal "hope-church-springfield", workspace.slug
  end

  test "keeps slugs unique when the derived slug is taken" do
    workspace = Workspace.create!(name: "St. Example")

    assert_not_equal "st-example", workspace.slug
    assert_match(/\Ast-example-[0-9a-f]{6}\z/, workspace.slug)
  end

  test "never derives a slug that would shadow a top-level route" do
    workspace = Workspace.create!(name: "Up")

    assert_not_equal "up", workspace.slug
  end

  test "requires a name" do
    assert_not Workspace.new(name: " ").valid?
  end
end
