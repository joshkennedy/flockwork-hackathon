require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "active excludes done, archived, and deleted projects by name" do
    workspace = workspaces(:st_example)
    workspace.projects.create!(
      name: "Still Active",
      owner: people(:leader),
      done_at: nil,
      archived_at: nil,
      deleted_at: nil
    )
    workspace.projects.create!(
      name: "Finished Project",
      owner: people(:leader),
      done_at: Time.current,
      archived_at: nil,
      deleted_at: nil
    )
    workspace.projects.create!(
      name: "Shelved Project",
      owner: people(:leader),
      done_at: nil,
      archived_at: Time.current,
      deleted_at: nil
    )
    workspace.projects.create!(
      name: "Removed Project",
      owner: people(:leader),
      done_at: nil,
      archived_at: nil,
      deleted_at: Time.current
    )

    active_names = workspace.projects.active.order(:name).pluck(:name)

    assert_equal [ "Building Cleanup", "Community Meal", "Still Active" ], active_names.sort
  end
end
