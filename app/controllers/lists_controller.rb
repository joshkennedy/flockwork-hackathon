class ListsController < ApplicationController
  before_action :set_project
  before_action :set_list, only: %i[ edit update destroy ]
  before_action :authorize_manage_lists

  def new
    @list = @project.lists.build
  end

  def create
    @list = @project.lists.build(list_params)

    if @list.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @list.update(list_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @list.destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_list
      @list = @project.lists.find(params[:id])
    end

    def authorize_manage_lists
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_lists, @project)
    end

    def list_params
      params.expect(list: [ :name ])
    end
end
