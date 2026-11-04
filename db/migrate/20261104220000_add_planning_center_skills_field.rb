class AddPlanningCenterSkillsField < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :pco_skills_field_id, :string
  end
end
