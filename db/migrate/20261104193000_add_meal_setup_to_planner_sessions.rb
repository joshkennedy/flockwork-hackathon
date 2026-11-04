class AddMealSetupToPlannerSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :planner_sessions, :meal_setup, :jsonb, null: false, default: {}
  end
end
