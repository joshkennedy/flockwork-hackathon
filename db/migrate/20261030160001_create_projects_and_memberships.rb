class CreateProjectsAndMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.date :starts_on
      t.date :ends_on
      t.references :owner, null: false, foreign_key: { to_table: :people }
      t.boolean :open_team, null: false, default: false
      t.string :public_token
      t.string :enabled_tools, array: true, null: false, default: []
      t.datetime :done_at
      t.datetime :archived_at
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :projects, :public_token, unique: true

    create_table :memberships do |t|
      t.references :project, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.integer :role, null: false

      t.timestamps
    end
    add_index :memberships, [ :project_id, :person_id ], unique: true
  end
end
