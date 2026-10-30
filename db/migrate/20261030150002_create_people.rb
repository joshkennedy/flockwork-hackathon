class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.boolean :admin, null: false, default: false
      t.datetime :last_signed_in_at
      t.string :external_source
      t.string :external_id

      t.timestamps
    end
    add_index :people, [ :workspace_id, :email ], unique: true, where: "email IS NOT NULL"
  end
end
