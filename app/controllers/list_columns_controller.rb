class ListColumnsController < ApplicationController
  before_action :set_project_and_list
  before_action :authorize_manage_lists
  before_action :set_column, only: %i[ edit update destroy move_up move_down ]

  def new
    @list_column = @list.columns.build
  end

  def create
    @list_column = @list.columns.build(list_column_params)

    if @list_column.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @list_column.update(list_column_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    ListColumn.transaction do
      @list.rows.find_each do |row|
        row.update!(cells: row.cells.except(@list_column.id.to_s))
      end
      @list_column.destroy!
    end

    redirect_to @project
  end

  def move_up
    @list_column.move_up!
    redirect_to @project
  end

  def move_down
    @list_column.move_down!
    redirect_to @project
  end

  private
    def set_project_and_list
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
      @list = @project.lists.find(params[:list_id])
    end

    def authorize_manage_lists
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_lists, @project)
    end

    def set_column
      @list_column = @list.columns.find(params[:id])
    end

    def list_column_params
      params.expect(list_column: [ :name, :column_type ])
    end
end
