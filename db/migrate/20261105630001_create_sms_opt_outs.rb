class CreateSmsOptOuts < ActiveRecord::Migration[8.1]
  def change
    create_table :sms_opt_outs do |t|
      t.string :phone, null: false
      t.datetime :opted_out_at, null: false
      t.jsonb :disabled_preferences, null: false, default: {}
      t.timestamps
    end
    add_index :sms_opt_outs, :phone, unique: true

    create_table :sms_webhook_events do |t|
      t.string :event_id, null: false
      t.timestamps
    end
    add_index :sms_webhook_events, :event_id, unique: true
  end
end
