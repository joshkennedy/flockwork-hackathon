class OrganizationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 5, within: 1.hour, by: -> { request.remote_ip }, only: :create, with: :organization_create_rate_limited

  def new
    redirect_to home_path if authenticated?
  end

  def show
    @organization = Current.organization
    @person = Current.person
    @pending_invitations = Policy.visible_invitations(Current.person).includes(:project).order(created_at: :desc)

    visible_project_ids = Policy.visible_projects(@person).select(:id)
    @any_projects = visible_project_ids.exists?
    @my_slots = Slot.joins(:slot_claims).where(project_id: visible_project_ids, slot_claims: { person_id: @person.id })
      .where(date: Date.current..).includes(:project).chronological
    @my_tasks = @organization.tasks.where(project_id: visible_project_ids, assignee_id: @person.id, completed_at: nil)
      .includes(:project, :rich_text_details).due_first
    @home_role = if @person.admin? then :admin elsif @person.memberships.leader.exists? then :leader else :volunteer end

    case @home_role
    when :admin
      @projects = Policy.visible_projects(@person).active.includes(memberships: :person).order(:starts_on, :name)
      project_ids = @projects.map(&:id)
      @open_spots_this_week = Slot.where(project_id: project_ids).this_week.with_open_spots.sum("capacity - claims_count")
      @unassigned_task_count = Task.open.where(project_id: project_ids, assignee_id: nil).count
      @people_count = @organization.people.count
    when :leader
      @projects = Current.organization.projects.active.where(id: @person.memberships.leader.select(:project_id)).order(:starts_on, :name)
    else
      member_project_ids = @person.memberships.select(:project_id)
      @projects = Current.organization.projects.active.where(id: member_project_ids).order(:starts_on, :name)
      @open_slots_by_project = Slot.open_this_week_by_project(member_project_ids)
      @open_teams = Current.organization.projects.active.where(open_team: true).where.not(id: member_project_ids).order(:starts_on, :name)
    end
  end

  def create
    @organization = Organization.new(name: organization_params[:church_name])
    @admin = @organization.people.build(name: organization_params[:your_name], email: organization_params[:email], admin: true)

    if @admin.valid?(:organization_creation) && @organization.save
      start_new_session_for @admin
      WelcomeMailer.welcome(@admin).deliver_later
      redirect_to home_path
    else
      flash.now[:alert] = (@organization.errors.full_messages + @admin.errors.full_messages).to_sentence
      render :new, status: :unprocessable_content
    end
  end

  private
    def organization_create_rate_limited
      flash.now[:alert] = "Too many sign-ups from this network. Try again in an hour."
      render :new, status: :too_many_requests
    end

    def organization_params
      params.permit(:church_name, :your_name, :email)
    end
end
