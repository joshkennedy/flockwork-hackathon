class CreateBudgetLines < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_lines do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :description, null: false
      t.integer :estimated_cents, null: false
      t.integer :actual_cents
      t.integer :status, null: false, default: 0
      t.references :responsible_person, foreign_key: { to_table: :people }

      t.timestamps
    end
  end
end
