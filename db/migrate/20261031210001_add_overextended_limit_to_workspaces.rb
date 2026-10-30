class AddOverextendedLimitToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :overextended_limit, :integer, null: false, default: 3
  end
end
