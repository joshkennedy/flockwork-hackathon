class RenameWorkspacesToOrganizations < ActiveRecord::Migration[8.1]
  def change
    rename_table :workspaces, :organizations

    %i[ invitations notes people projects ].each do |table|
      rename_column table, :workspace_id, :organization_id
    end

    # Custom-named index that rename_column leaves alone.
    rename_index :people, "index_people_on_workspace_and_external_identity", "index_people_on_organization_and_external_identity"
  end
end
