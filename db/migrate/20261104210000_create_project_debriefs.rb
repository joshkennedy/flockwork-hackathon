class CreateProjectDebriefs < ActiveRecord::Migration[8.1]
  def change
    create_table :project_debriefs do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.text :what_worked, null: false, default: ""
      t.text :change_next_time, null: false, default: ""
      t.timestamps
    end
  end
end
