class AddPendingEmailToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :pending_email, :string
  end
end
