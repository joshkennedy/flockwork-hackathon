class CreateMentions < ActiveRecord::Migration[8.1]
  def change
    create_table :mentions do |t|
      t.references :mentionable, polymorphic: true, null: false
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end

    add_index :mentions,
      [ :mentionable_type, :mentionable_id, :person_id ],
      unique: true,
      name: "index_mentions_on_mentionable_and_person"
  end
end
