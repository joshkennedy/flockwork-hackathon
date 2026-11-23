# Planner answers now advance on their own, so sessions left waiting on the removed Continue step move ahead the same way.
class AdvancePlannerSessionsWaitingForContinue < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE planner_sessions
      SET current_card = prepared_card,
        status = CASE WHEN prepared_card IS NULL THEN 1 ELSE status END,
        prepared_card = NULL,
        pending_answer = NULL,
        generation_state = 'idle',
        generation_revision = generation_revision + 1,
        updated_at = CURRENT_TIMESTAMP
      WHERE generation_state = 'ready'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
