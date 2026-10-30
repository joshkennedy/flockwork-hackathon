class MyTasksController < ApplicationController
  def index
    visible_project_ids = Policy.visible_projects(Current.person).select(:id)
    @tasks = Current.workspace.tasks
      .where(project_id: visible_project_ids, assignee_id: Current.person.id, completed_at: nil)
      .includes(:project, :rich_text_details)
      .due_first
  end
end
