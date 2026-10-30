class CreateCommentsAndFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :commentable, polymorphic: true, null: false
      t.references :author, null: false, foreign_key: { to_table: :people }

      t.timestamps
    end

    create_table :follows do |t|
      t.references :followable, polymorphic: true, null: false
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end

    add_index :follows,
      [ :followable_type, :followable_id, :person_id ],
      unique: true,
      name: "index_follows_on_followable_and_person"
  end
end
