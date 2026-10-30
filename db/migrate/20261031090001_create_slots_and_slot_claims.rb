class CreateSlotsAndSlotClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :slots do |t|
      t.references :project, null: false, foreign_key: true
      t.date :date, null: false
      t.time :starts_at_time
      t.string :label, null: false
      t.integer :capacity, null: false, default: 1
      t.integer :claims_count, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :slots, "capacity >= 1", name: "slots_capacity_at_least_one"

    create_table :slot_claims do |t|
      t.references :slot, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end

    add_index :slot_claims, [ :slot_id, :person_id ], unique: true
  end
end
