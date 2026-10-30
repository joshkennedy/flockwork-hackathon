class PublicProjectsController < ApplicationController
  layout "public"

  allow_unauthenticated_access only: :show

  def show
    @project = Project.find_by!(public_token: params[:token])
    raise ActiveRecord::RecordNotFound if @project.archived_at.present? || @project.deleted_at.present?

    @workspace = @project.workspace
    @schedule_items_by_day = @project.schedule_items.grouped_by_day
    @open_tasks = @project.tasks.open.where(assignee_id: nil).due_first
    @open_slots = @project.slots.chronological.where("claims_count < capacity")
    @sign_in_path = new_sign_in_request_path(@workspace)
  end
end
