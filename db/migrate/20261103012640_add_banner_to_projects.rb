class AddBannerToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :banner_focus_x, :float, null: false, default: 0.5
    add_column :projects, :banner_focus_y, :float, null: false, default: 0.5
    add_column :projects, :banner_focus_manual, :boolean, null: false, default: false
    add_column :projects, :banner_alt_text, :string
  end
end
