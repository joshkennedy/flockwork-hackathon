class AddRemovedAtToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :removed_at, :datetime
    add_index :people, :removed_at
  end
end
