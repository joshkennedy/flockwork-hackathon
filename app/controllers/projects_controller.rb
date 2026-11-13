class ProjectsController < ApplicationController
  before_action :set_project, only: %i[
    show edit update join mark_done reopen archive unarchive transfer_ownership destroy team
    enable_public_link reset_public_link disable_public_link
  ]
  before_action :set_deleted_project, only: :restore
  before_action :authorize_project_write, only: %i[ edit update ]
  before_action :authorize_deleted_list, only: :deleted
  before_action :authorize_project_team, only: :team
  rate_limit to: 10, within: 1.hour, by: -> { Current.person.id }, name: "planner_spend", scope: :planner,
    only: %i[start_planner start_meal_planner], with: :start_planner_rate_limited

  def index
    @projects = Policy.listed_projects(Current.person).with_attached_banner.order(:name)
  end

  def archived
    @projects = Policy.archived_projects(Current.person).order(:name)
  end

  def deleted
    @projects = Policy.deleted_projects(Current.person).order(:name)
  end

  def show
    load_team if Policy.can?(Current.person, :view_team, @project)
    if Policy.can?(Current.person, :plan, @project)
      @resumable_planner_session = @project.planner_sessions.where(flow_version: [ 2, 3, 4 ], started_by: Current.person, status: %i[asking reviewing]).order(updated_at: :desc).first
      @completed_planner_session = @project.planner_sessions.where(flow_version: [ 2, 3, 4 ], status: :accepted).find_by(id: params[:added_plan]) if params[:added_plan].present?
    end
    @ownership_transfer_leaders = @project.memberships.leader.where.not(person_id: @project.owner_id).includes(:person)
    return unless Policy.can?(Current.person, :view_notes, @project)

    @project_notes = Policy.visible_notes(Current.person, @project.notes).includes(:author).order(:created_at, :id)
    recipient_scope = Current.organization.notes.where(notable_type: "Recipient", notable_id: @project.recipient_ids)
    @recipient_notes_by_id = Policy.visible_notes(Current.person, recipient_scope)
      .includes(:author).order(:created_at, :id).group_by(&:notable_id)
    @note_visibilities = Policy.writable_note_visibilities(Current.person, @project)
  end

  # Team is a tab on the project page; this URL opens the page with that tab selected.
  def team
    @selected_tab = "team"
    show
    render :show
  end

  def new
    authorize_project_creation
    @project = Current.organization.projects.new
    @manual_project = params[:manual].present?
    @custom_planning = params[:planning_kind] == "other"
  end

  def start_meal_planner
    authorize_project_creation
    start_planning("meal_train")
  end

  def start_planner
    authorize_project_creation
    kind = params.expect(:planning_kind)
    raise ActionController::BadRequest, "Choose a Project type" unless Planner::ProjectKinds::CHOICES.key?(kind)

    description = params.expect(planner_session: [ :description ])[:description].to_s.strip if kind == "other"
    if kind == "other" && description.blank?
      @project = Current.organization.projects.new
      @custom_planning = true
      @description_error = "Describe what you're organizing in one sentence."
      return render :new, status: :unprocessable_content
    end

    start_planning(kind, description:)
  end

  def create
    authorize_project_creation
    @project = Project.create_for(creator: Current.person, attributes: project_params)

    if @project.persisted?
      redirect_to @project
    else
      @manual_project = true
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Saved #{@project.name}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def join
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :join, @project)

    @project.memberships.find_or_create_by!(person: Current.person) do |membership|
      membership.role = :volunteer
    end
    redirect_to params[:from] == "get_involved" ? get_involved_path : @project
  end

  def mark_done
    authorize_lifecycle(:mark_done)
    @project.update!(done_at: Time.current)
    redirect_to edit_project_debrief_path(@project)
  end

  def reopen
    authorize_lifecycle(:reopen)
    @project.update!(done_at: nil)
    redirect_to @project
  end

  def archive
    authorize_lifecycle(:archive)
    @project.update!(archived_at: Time.current)
    redirect_to archived_projects_path
  end

  def unarchive
    authorize_lifecycle(:unarchive)
    @project.update!(archived_at: nil)
    redirect_to @project
  end

  def transfer_ownership
    authorize_lifecycle(:transfer_ownership)
    new_owner = Current.organization.people.find(params[:new_owner_id])
    raise ActiveRecord::RecordNotFound unless @project.memberships.leader.exists?(person: new_owner)

    @project.update!(owner: new_owner)
    redirect_to @project, notice: "#{new_owner.name} now owns #{@project.name}."
  end

  def destroy
    authorize_lifecycle(:destroy)
    @project.soft_delete!
    redirect_to projects_path, notice: "Deleted #{@project.name}."
  end

  def restore
    authorize_lifecycle(:restore)
    @project.update!(deleted_at: nil)
    redirect_to @project
  end

  def enable_public_link
    authorize_public_link
    @project.enable_public_link!
    redirect_to @project
  end

  def reset_public_link
    authorize_public_link
    @project.reset_public_link!
    redirect_to @project
  end

  def disable_public_link
    authorize_public_link
    @project.disable_public_link!
    redirect_to @project
  end

  private

    def load_team
      @memberships = @project.memberships.includes(:person).order(:role, :created_at)
      @can_manage_team = Policy.can?(Current.person, :manage_team, @project)
      return unless @can_manage_team

      @invitations = Current.organization.invitations.where(project: @project).includes(:person).order(created_at: :desc)
      @staffing_suggestions = StaffingSuggestions.new(@project).call
      return unless params[:query].present?

      member_ids = @project.memberships.select(:person_id)
      @directory_people = Current.organization.people
        .matching(params[:query])
        .where.not(id: member_ids)
        .order(:name)
        .limit(50)
    end

    def start_planning(kind, description: nil)
      starter = Planner::ProjectKinds::CHOICES.fetch(kind)
      Project.transaction do
        project_attributes = starter.slice(:description).merge(
          name: Planner::ProjectKinds.provisional_name(kind, description:),
          enabled_tools: []
        )
        @project = Project.create_for(creator: Current.person, attributes: project_attributes)
        @project.save!
        @planner_session = @project.planner_sessions.create!(
          started_by: Current.person, flow_version: kind == "meal_train" ? 4 : 3,
          planning_kind: kind, description: description.presence || starter.fetch(:prompt)
        )
        if @planner_session.meal_setup?
          @planner_session.save_meal_setup!(MealTrainPlan.new.attributes, expected_revision: 0)
        else
          @revision = @planner_session.queue_generation!
        end
      end
      PlannerStepJob.perform_later(
        @project.id,
        @planner_session.id,
        Current.session.id,
        Current.person.id,
        @revision
      ) if @revision
      redirect_to project_planner_session_path(@project, @planner_session), status: :see_other
    end

    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      # A helper who claimed a Slot from the Public link is not on the Team, so reminders and Home send them
      # here for a page they cannot open. Their own way in is the Public page.
      claimed = Current.organization.projects.publicly_linked
        .find_by(id: Current.person.slot_claims.joins(:slot).where(slots: { project_id: params[:id] }).select("slots.project_id"))
      raise unless claimed && action_name == "show"

      redirect_to public_project_path(claimed.public_token)
    end

    def set_deleted_project
      @project = Policy.deleted_projects(Current.person).find(params[:id])
    end

    def authorize_project_creation
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :create, Project)
    end

    def authorize_project_write
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :update, @project)
      return unless params.dig(:project, :enabled_tools)

      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_tools, @project)
    end

    def authorize_lifecycle(action)
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, action, @project)
    end

    def authorize_deleted_list
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_deleted, ::Project)
    end

    def authorize_project_team
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_team, @project)
    end

    def authorize_public_link
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_public_link, @project)
    end

    def start_planner_rate_limited
      redirect_to new_project_path, alert: "Too many planning requests. Try again in an hour.", status: :see_other
    end

    def project_params
      permitted = params.expect(project: [ :name, :description, :starts_on, :ends_on, :open_team, enabled_tools: [], skills_needed: [] ])
      permitted[:enabled_tools] = permitted[:enabled_tools].compact_blank if permitted.key?(:enabled_tools)
      permitted
    end
end
