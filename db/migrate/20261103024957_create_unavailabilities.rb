class CreateUnavailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :unavailabilities do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :note

      t.timestamps
    end
  end
end
