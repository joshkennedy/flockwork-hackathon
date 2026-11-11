class ProjectRecurrencesController < ApplicationController
  before_action :set_project

  def edit
    @recurrence = @project.project_recurrence || @project.build_project_recurrence(frequency: :weekly)
  end

  def update
    @recurrence = @project.project_recurrence || @project.build_project_recurrence(anchor_on: @project.starts_on)
    @recurrence.assign_attributes(params.expect(project_recurrence: [ :frequency, :enabled ]))
    @recurrence.creator = Current.person

    if @recurrence.save
      redirect_to @project, notice: "Repeat settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
      raise ActiveRecord::RecordNotFound unless @project.active? && Policy.can?(Current.person, :duplicate, @project)
    end
end
