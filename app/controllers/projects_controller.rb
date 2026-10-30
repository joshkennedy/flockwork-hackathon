class ProjectsController < ApplicationController
  before_action :set_project, only: %i[
    show edit update join mark_done reopen archive unarchive transfer_ownership destroy team
    enable_public_link reset_public_link disable_public_link
  ]
  before_action :set_deleted_project, only: :restore
  before_action :authorize_project_write, only: %i[ edit update ]
  before_action :authorize_deleted_list, only: :deleted
  before_action :authorize_project_team, only: :team

  def index
    @projects = Policy.listed_projects(Current.person).order(:name)
  end

  def archived
    @projects = Policy.archived_projects(Current.person).order(:name)
  end

  def deleted
    @projects = Policy.deleted_projects(Current.person).order(:name)
  end

  def show
    @ownership_transfer_leaders = @project.memberships.leader.where.not(person_id: @project.owner_id).includes(:person)
    return unless Policy.can?(Current.person, :view_notes, @project)

    @project_notes = Policy.visible_notes(Current.person, @project.notes).includes(:author).order(:created_at, :id)
    recipient_scope = Current.workspace.notes.where(notable_type: "Recipient", notable_id: @project.recipient_ids)
    @recipient_notes_by_id = Policy.visible_notes(Current.person, recipient_scope)
      .includes(:author).order(:created_at, :id).group_by(&:notable_id)
    @note_visibilities = Policy.writable_note_visibilities(Current.person, @project)
  end

  def team
    @memberships = @project.memberships.includes(:person).order(:role, :created_at)
    @can_manage_team = Policy.can?(Current.person, :manage_team, @project)
    return unless @can_manage_team

    @invitations = Current.workspace.invitations.where(project: @project).includes(:person).order(created_at: :desc)
    return unless params[:query].present?

    member_ids = @project.memberships.select(:person_id)
    @directory_people = Current.workspace.people
      .where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%")
      .where.not(id: member_ids)
      .order(:name)
  end

  def new
    authorize_project_creation
    @project = Current.workspace.projects.new
  end

  def create
    authorize_project_creation
    @project = Project.create_for(creator: Current.person, attributes: project_params)

    if @project.persisted?
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def join
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :join, @project)

    @project.memberships.find_or_create_by!(person: Current.person) do |membership|
      membership.role = :volunteer
    end
    redirect_to @project
  end

  def mark_done
    authorize_lifecycle(:mark_done)
    @project.update!(done_at: Time.current)
    redirect_to @project
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
    new_owner = Current.workspace.people.find(params[:new_owner_id])
    raise ActiveRecord::RecordNotFound unless @project.memberships.leader.exists?(person: new_owner)

    @project.update!(owner: new_owner)
    redirect_to @project
  end

  def destroy
    authorize_lifecycle(:destroy)
    @project.update!(deleted_at: Time.current)
    redirect_to projects_path
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
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:id])
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

    def project_params
      permitted = params.expect(project: [ :name, :description, :starts_on, :ends_on, :open_team, enabled_tools: [] ])
      permitted[:enabled_tools] = permitted[:enabled_tools].compact_blank if permitted.key?(:enabled_tools)
      permitted
    end
end
