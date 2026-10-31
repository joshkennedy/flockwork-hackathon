class AddBuildAsYouGoStateToPlannerSessions < ActiveRecord::Migration[8.1]
  def change
    change_table :planner_sessions, bulk: true do |t|
      t.integer :flow_version, null: false, default: 1
      t.integer :generation_revision, null: false, default: 0
      t.string :generation_state, null: false, default: "idle"
      t.jsonb :prepared_card
      t.jsonb :pending_answer
      t.jsonb :pending_items, null: false, default: []
      t.datetime :accepted_at
    end
  end
end
