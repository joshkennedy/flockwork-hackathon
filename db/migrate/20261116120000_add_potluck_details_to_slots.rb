class AddPotluckDetailsToSlots < ActiveRecord::Migration[8.1]
  def change
    add_column :slots, :claim_prompt, :string, limit: 120
    add_column :slot_claims, :note, :string, limit: 80
  end
end
