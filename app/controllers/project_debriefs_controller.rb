class ProjectDebriefsController < ApplicationController
  before_action :set_project

  def edit
    @debrief = @project.project_debrief || @project.build_project_debrief
  end

  def update
    attributes = params.expect(project_debrief: [ :what_worked, :change_next_time ])
    saved = @project.with_lock do
      @debrief = @project.project_debrief || @project.build_project_debrief
      @debrief.update(attributes)
    end
    if saved
      redirect_to @project, notice: "Debrief saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
      raise ActiveRecord::RecordNotFound unless @project.done_at? && Policy.can?(Current.person, :edit_debrief, @project)
    end
end
