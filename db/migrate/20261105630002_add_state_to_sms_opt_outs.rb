class AddStateToSmsOptOuts < ActiveRecord::Migration[8.1]
  def change
    add_column :sms_opt_outs, :opted_out, :boolean, null: false, default: true
    add_column :sms_opt_outs, :last_event_at, :datetime, null: false, default: -> { "to_timestamp(0)" }
  end
end
