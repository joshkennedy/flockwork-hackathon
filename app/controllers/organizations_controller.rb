class OrganizationsController < ApplicationController
  allow_unauthenticated_access only: :create

  def show
    @organization = Current.organization
    @person = Current.person
    @pending_invitations = Policy.visible_invitations(Current.person).includes(:project).order(created_at: :desc)

    visible_project_ids = Policy.visible_projects(@person).select(:id)
    week = Date.current..(Date.current + 6)
    @any_projects = visible_project_ids.exists?
    @my_slots = Slot.joins(:slot_claims).where(project_id: visible_project_ids, date: week, slot_claims: { person_id: @person.id })
      .includes(:project).chronological
    @my_tasks = @organization.tasks.where(project_id: visible_project_ids, assignee_id: @person.id, completed_at: nil)
      .includes(:project).due_first.limit(5)
    @open_slots_by_project = Slot.where(project_id: visible_project_ids, date: week).where("claims_count < capacity")
      .includes(:project).chronological.group_by(&:project)
  end

  def create
    @organization = Organization.new(name: organization_params[:church_name])
    @admin = @organization.people.build(name: organization_params[:your_name], email: organization_params[:email], admin: true)

    if @admin.valid?(:organization_creation) && @organization.save
      start_new_session_for @admin
      redirect_to home_path
    else
      redirect_to root_path, alert: (@organization.errors.full_messages + @admin.errors.full_messages).to_sentence
    end
  end

  private
    def organization_params
      params.permit(:church_name, :your_name, :email)
    end
end
