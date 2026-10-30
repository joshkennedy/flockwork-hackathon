class CreateDocItems < ActiveRecord::Migration[8.1]
  def change
    create_table :doc_items do |t|
      t.references :project, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :people }
      t.integer :kind, null: false
      t.string :title, null: false
      t.string :url

      t.timestamps
    end
  end
end
