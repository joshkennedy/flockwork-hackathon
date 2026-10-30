class CreateScheduleItems < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_items do |t|
      t.references :project, null: false, foreign_key: true
      t.date :date, null: false
      t.time :starts_at_time
      t.time :ends_at_time
      t.string :title, null: false
      t.string :location

      t.timestamps
    end
  end
end
