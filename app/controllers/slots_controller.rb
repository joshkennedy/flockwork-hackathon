class SlotsController < ApplicationController
  before_action :set_project
  before_action :set_slot, only: %i[ edit update destroy ]
  before_action :authorize_manage_slots

  def new
    @slot = @project.slots.build
  end

  def create
    @slot = @project.slots.build(slot_params)

    if @slot.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @slot.update(slot_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @slot.destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_slot
      @slot = @project.slots.find(params[:id])
    end

    def authorize_manage_slots
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_slots, @project)
    end

    def slot_params
      params.expect(slot: [ :date, :starts_at_time, :label, :capacity ])
    end
end
