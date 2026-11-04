class CreateProjectRecurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :project_recurrences do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.references :creator, null: false, foreign_key: { to_table: :people }
      t.string :frequency, null: false
      t.date :anchor_on, null: false
      t.boolean :enabled, null: false, default: false
      t.timestamps
    end

    create_table :project_occurrences do |t|
      t.references :project_recurrence, null: false, foreign_key: true
      t.references :project, foreign_key: { on_delete: :nullify }, index: { unique: true }
      t.date :on, null: false
      t.timestamps
      t.index [ :project_recurrence_id, :on ], unique: true
    end
  end
end
