class AllowNullEstimatesOnBudgetLines < ActiveRecord::Migration[8.1]
  def change
    change_column_null :budget_lines, :estimated_cents, true
  end
end
