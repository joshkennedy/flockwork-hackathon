class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :project, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :people }
      t.references :parent, foreign_key: { to_table: :messages }

      t.timestamps
    end
  end
end
