class CreateSignInChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_challenges do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :cascade }
      t.references :project, foreign_key: { on_delete: :cascade }
      t.string :channel, null: false
      t.string :address, null: false
      t.string :code_digest
      t.integer :attempts, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps

      t.index %i[ organization_id address ]
    end

    add_reference :people, :joined_from_project, foreign_key: { to_table: :projects, on_delete: :nullify }
  end
end
