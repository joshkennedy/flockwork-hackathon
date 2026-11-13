class PublicProjectsController < ApplicationController
  layout "public"

  allow_unauthenticated_access only: :show

  def show
    @project = Project.publicly_linked.find_by!(public_token: params[:token])
    @organization = @project.organization
    @schedule_items_by_day = @project.schedule_items.grouped_by_day
    # Someone signed in to this Organization claims here; everyone else is sent to sign in first.
    @helper = Current.person if authenticated? && Policy.can?(Current.person, :claim_public_slot, @project)
    @on_team = @helper && Policy.member?(@helper, @project)
    # Tasks are Team work, and helpers from the Public link stay off the Team, so only the Team sees them here.
    @open_tasks = @on_team ? @project.tasks.open.where(assignee_id: nil).due_first : Task.none
    @claimed_slot_ids = @helper ? @helper.slot_claims.where(slot_id: @project.slots.select(:id)).pluck(:slot_id) : []
    # Past Slots are over, so helpers see only what they can still bring.
    @open_slots = @project.slots.chronological.where("claims_count < capacity").or(@project.slots.where(id: @claimed_slot_ids))
      .where(date: Date.current..)
  end
end
