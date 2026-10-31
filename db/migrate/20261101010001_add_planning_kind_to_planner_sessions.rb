class AddPlanningKindToPlannerSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :planner_sessions, :planning_kind, :string, null: false, default: "meal_train"
  end
end
