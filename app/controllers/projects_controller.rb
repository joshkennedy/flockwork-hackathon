class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update ]
  before_action :authorize_project_write, only: %i[ edit update ]

  def index
    @projects = Policy.visible_projects(Current.person).order(:name)
  end

  def show
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

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:id])
    end

    def authorize_project_creation
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :create, Project)
    end

    def authorize_project_write
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :update, @project)
      return unless params.dig(:project, :enabled_tools)

      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_tools, @project)
    end

    def project_params
      permitted = params.expect(project: [ :name, :description, :starts_on, :ends_on, enabled_tools: [] ])
      permitted[:enabled_tools] = permitted[:enabled_tools].compact_blank if permitted.key?(:enabled_tools)
      permitted
    end
end
