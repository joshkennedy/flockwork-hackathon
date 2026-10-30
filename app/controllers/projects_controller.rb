class ProjectsController < ApplicationController
  before_action :set_project, only: %i[
    show edit update mark_done reopen archive unarchive transfer_ownership destroy
  ]
  before_action :set_deleted_project, only: :restore
  before_action :authorize_project_write, only: %i[ edit update ]
  before_action :authorize_deleted_list, only: :deleted

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

    def project_params
      permitted = params.expect(project: [ :name, :description, :starts_on, :ends_on, enabled_tools: [] ])
      permitted[:enabled_tools] = permitted[:enabled_tools].compact_blank if permitted.key?(:enabled_tools)
      permitted
    end
end
