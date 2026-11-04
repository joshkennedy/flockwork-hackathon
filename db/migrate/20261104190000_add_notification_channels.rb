class AddNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :in_app_preferences, :jsonb, default: {}, null: false
    add_column :people, :sms_preferences, :jsonb, default: {}, null: false
    add_column :notifications, :in_app, :boolean, default: true, null: false
    add_column :notifications, :sms_payload, :jsonb, default: {}, null: false
    add_column :notifications, :sms_message_id, :string
    add_column :notifications, :sms_status, :string
    add_column :notifications, :sms_simulated, :boolean
    add_column :notifications, :sms_error, :string
  end
end
