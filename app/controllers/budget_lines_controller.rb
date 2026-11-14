class BudgetLinesController < ApplicationController
  before_action :set_project
  before_action :set_budget_line, only: %i[ edit update destroy ]
  before_action :authorize_manage_budget

  def new
    @budget_line = @project.budget_lines.build(kind: params[:kind].presence_in(BudgetLine.kinds.keys) || "booking")
    @team_people = team_people
  end

  def create
    @budget_line = @project.budget_lines.build(budget_line_params)
    @team_people = team_people

    if @budget_line.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @team_people = team_people
  end

  def update
    @team_people = team_people

    if @budget_line.update(budget_line_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @budget_line.destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_budget_line
      @budget_line = @project.budget_lines.find(params[:id])
    end

    def authorize_manage_budget
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_budget, @project)
    end

    def team_people
      @project.people.order(:name)
    end

    def budget_line_params
      params.expect(budget_line: [ :kind, :description, :estimated, :responsible_person_id ])
    end
end
