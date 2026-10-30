class BudgetLineStatusesController < ApplicationController
  before_action :set_project
  before_action :set_budget_line
  before_action :authorize_update_budget_line_status

  def edit
  end

  def update
    if @budget_line.update(status_update_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_budget_line
      @budget_line = @project.budget_lines.find(params[:budget_line_id])
    end

    def authorize_update_budget_line_status
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :update_budget_line_status, @budget_line)
    end

    def status_update_params
      params.expect(budget_line: [ :status, :actual ])
    end
end
