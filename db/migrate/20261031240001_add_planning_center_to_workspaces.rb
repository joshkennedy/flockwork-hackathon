class AddPlanningCenterToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    change_table :workspaces, bulk: true do |t|
      t.text :pco_app_id
      t.text :pco_secret
      t.datetime :pco_last_synced_at
      t.jsonb :pco_last_sync_result, null: false, default: {}
      t.text :pco_last_sync_error
    end

    add_index :people, [ :workspace_id, :external_source, :external_id ],
      unique: true,
      where: "external_id IS NOT NULL",
      name: "index_people_on_workspace_and_external_identity"
  end
end
