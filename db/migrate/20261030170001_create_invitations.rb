class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :people }
      t.integer :role, null: false
      t.integer :status, null: false, default: 0
      t.datetime :responded_at

      t.timestamps
    end

    add_index :invitations, [ :project_id, :person_id ], unique: true,
      where: "status = 0", name: "index_invitations_on_pending_project_and_person"
  end
end
