class CreateCheckIns < ActiveRecord::Migration[8.1]
  def change
    create_table :check_ins do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :checked_in_by, foreign_key: { to_table: :people }
      t.date :on, null: false
      t.string :note

      t.timestamps
    end
  end
end
