class SlotRunsController < ApplicationController
  before_action :set_project
  before_action :authorize_manage_slots

  def new
    @slot_run = SlotRun.new(project: @project)
  end

  def create
    @slot_run = SlotRun.new(project: @project, **slot_run_params.to_h.symbolize_keys)

    if @slot_run.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def authorize_manage_slots
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_slots, @project)
    end

    def slot_run_params
      params.expect(slot_run: [ :start_date, :end_date, :starts_at_time, :label, :capacity ])
    end
end
