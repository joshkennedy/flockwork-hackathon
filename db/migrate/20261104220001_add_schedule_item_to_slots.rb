class AddScheduleItemToSlots < ActiveRecord::Migration[8.1]
  def change
    add_reference :slots, :schedule_item, foreign_key: { on_delete: :nullify }
  end
end
