class AddAddedByToPeople < ActiveRecord::Migration[8.1]
  def change
    add_reference :people, :added_by, null: true, foreign_key: { to_table: :people, on_delete: :nullify }
  end
end
