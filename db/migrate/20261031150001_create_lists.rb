class CreateLists < ActiveRecord::Migration[8.1]
  def change
    create_table :lists do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    create_table :list_columns do |t|
      t.references :list, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :column_type, null: false
      t.integer :position, null: false

      t.timestamps
    end

    create_table :list_rows do |t|
      t.references :list, null: false, foreign_key: true
      t.integer :position, null: false
      t.jsonb :cells, null: false, default: {}

      t.timestamps
    end
  end
end
