class PlannerSessionsController < ApplicationController
  before_action :set_project
  before_action :authorize_plan
  before_action :set_planner_session, except: %i[ new create ]

  def new
    @planner_session = @project.planner_sessions.build
  end

  def create
    @planner_session = @project.planner_sessions.build(
      planner_session_params.merge(started_by: Current.person)
    )

    if @planner_session.save
      @planner_session.start!
      redirect_to planner_destination
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    redirect_to planner_destination unless @planner_session.asking?
  end

  def answer
    raise ActiveRecord::RecordNotFound unless @planner_session.asking?

    @planner_session.answer!(params.expect(:answer))
    redirect_to planner_destination
  end

  def review
    raise ActiveRecord::RecordNotFound unless @planner_session.reviewing?
  end

  def skip_to_review
    raise ActiveRecord::RecordNotFound unless @planner_session.asking?

    @planner_session.skip_to_review!
    redirect_to review_project_planner_session_path(@project, @planner_session)
  end

  def abandon
    raise ActiveRecord::RecordNotFound unless @planner_session.asking?

    @planner_session.abandon!
    redirect_to @project
  end

  def suggestion
    raise ActiveRecord::RecordNotFound unless @planner_session.reviewing?

    values = params.expect(suggestion: [ :id, :decision, :title, :details ])
    @planner_session.decide_suggestion!(**values.to_h.symbolize_keys)
    redirect_to review_project_planner_session_path(@project, @planner_session)
  end

  def accept
    raise ActiveRecord::RecordNotFound unless @planner_session.reviewing?

    @planner_session.accept!(include_proposed: params[:mode] == "all")
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def authorize_plan
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :plan, @project)
    end

    def set_planner_session
      @planner_session = @project.planner_sessions.find(params[:id])
    end

    def planner_session_params
      params.expect(planner_session: [ :description ])
    end

    def planner_destination
      if @planner_session.reviewing?
        review_project_planner_session_path(@project, @planner_session)
      elsif @planner_session.accepted? || @planner_session.abandoned?
        project_path(@project)
      else
        project_planner_session_path(@project, @planner_session)
      end
    end
end
