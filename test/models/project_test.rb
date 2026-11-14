require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "a Project name is limited to 120 characters" do
    project = projects(:community_meal)
    project.name = "P" * 121

    assert_not project.valid?
    assert_includes project.errors.full_messages, "Name is too long (maximum is 120 characters)"
  end

  test "active excludes done, archived, and deleted projects by name" do
    organization = organizations(:st_example)
    organization.projects.create!(
      name: "Still Active",
      owner: people(:leader),
      done_at: nil,
      archived_at: nil,
      deleted_at: nil
    )
    organization.projects.create!(
      name: "Finished Project",
      owner: people(:leader),
      done_at: Time.current,
      archived_at: nil,
      deleted_at: nil
    )
    organization.projects.create!(
      name: "Shelved Project",
      owner: people(:leader),
      done_at: nil,
      archived_at: Time.current,
      deleted_at: nil
    )
    organization.projects.create!(
      name: "Removed Project",
      owner: people(:leader),
      done_at: nil,
      archived_at: nil,
      deleted_at: Time.current
    )

    active_names = organization.projects.active.order(:name).pluck(:name)

    assert_equal [ "Building Cleanup", "Community Meal", "Still Active" ], active_names.sort
  end
end
