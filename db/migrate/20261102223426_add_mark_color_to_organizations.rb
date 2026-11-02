class AddMarkColorToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :mark_color, :string, null: false, default: "#D69000"
  end
end
