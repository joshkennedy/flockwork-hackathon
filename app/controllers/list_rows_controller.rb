class ListRowsController < ApplicationController
  before_action :set_project_and_list
  before_action :authorize_manage_rows
  before_action :set_row, only: %i[ edit update destroy toggle_checkbox ]

  def new
    @list_row = @list.rows.build
  end

  def create
    @list_row = @list.rows.build

    if @list_row.assign_cast_cells(raw_cells) && @list_row.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @list_row.assign_cast_cells(raw_cells) && @list_row.save
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @list_row.destroy!
    redirect_to @project
  end

  def toggle_checkbox
    @list_column = @list.columns.find(params[:column_id])
    raise ActiveRecord::RecordNotFound unless @list_column.checkbox?

    key = @list_column.id.to_s
    @list_row.update!(cells: @list_row.cells.merge(key => !@list_row.cells[key]))

    if turbo_frame_request?
      render partial: "list_rows/checkbox_cell", locals: {
        project: @project,
        list: @list,
        list_row: @list_row,
        column: @list_column
      }
    else
      redirect_to @project
    end
  end

  private
    def set_project_and_list
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
      @list = @project.lists.find(params[:list_id])
    end

    def authorize_manage_rows
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_list_rows, @project)
    end

    def set_row
      @list_row = @list.rows.find(params[:id])
    end

    def raw_cells
      params.expect(list_row: [ cells: {} ]).fetch(:cells, {})
    end
end
