class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :notable, polymorphic: true, null: false
      t.references :author, null: false, foreign_key: { to_table: :people }
      t.integer :visibility, null: false, default: 0
      t.text :body, null: false

      t.timestamps
    end
  end
end
