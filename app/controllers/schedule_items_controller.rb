class ScheduleItemsController < ApplicationController
  before_action :set_project
  before_action :set_schedule_item, only: %i[ edit update destroy ]
  before_action :authorize_manage_schedule

  def new
    @schedule_item = @project.schedule_items.build
  end

  def create
    @schedule_item = @project.schedule_items.build(schedule_item_params)

    if @schedule_item.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @schedule_item.update(schedule_item_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @schedule_item.destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_schedule_item
      @schedule_item = @project.schedule_items.find(params[:id])
    end

    def authorize_manage_schedule
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_schedule, @project)
    end

    def schedule_item_params
      params.expect(schedule_item: [ :date, :starts_at_time, :ends_at_time, :title, :location ])
    end
end
