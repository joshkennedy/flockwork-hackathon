class CreatePlannerSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :planner_sessions do |t|
      t.references :project, null: false, foreign_key: true
      t.references :started_by, null: false, foreign_key: { to_table: :people }
      t.text :description, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :steps, null: false, default: []
      t.jsonb :current_card
      t.jsonb :suggestions, null: false, default: []
      t.text :last_error

      t.timestamps
    end
  end
end
