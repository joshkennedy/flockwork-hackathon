class AddSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :skills, :string, array: true, default: [], null: false
    add_index :people, :skills, using: :gin
    add_column :projects, :skills_needed, :string, array: true, default: [], null: false
  end
end
