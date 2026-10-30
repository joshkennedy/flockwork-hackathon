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
    redirect_to planner_destination unless @planner_session.asking? || request.headers["Turbo-Frame"].present?
  end

  def answer
    raise ActiveRecord::RecordNotFound unless @planner_session.asking?

    @planner_session.record_answer!(params.expect(:answer))
    PlannerStepJob.perform_later(@project.id, @planner_session.id, Current.session.id)
    redirect_to project_planner_session_path(@project, @planner_session)
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
    raise ActiveRecord::RecordNotFound unless @planner_session.asking? || @planner_session.reviewing?

    values = params.expect(
      suggestion: [
        :id,
        :decision,
        :title,
        :details,
        { fields: Planner::SuggestionKinds.permitted_fields }
      ]
    ).to_h.symbolize_keys
    values[:fields] = values[:fields].to_h.deep_stringify_keys if values[:fields]
    @planner_session.decide_suggestion!(**values)

    if request.headers["Turbo-Frame"] == helpers.dom_id(@planner_session, :summary)
      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@planner_session, :summary),
        partial: "planner_sessions/summary",
        locals: { planner_session: @planner_session }
      )
    else
      redirect_to planner_destination
    end
  end

  def accept
    raise ActiveRecord::RecordNotFound unless @planner_session.reviewing?

    @planner_session.accept!(include_proposed: params[:mode] == "all")
    redirect_to @project
  rescue ArgumentError => error
    redirect_to review_project_planner_session_path(@project, @planner_session), alert: error.message
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
