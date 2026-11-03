class PlannerSessionsController < ApplicationController
  before_action :set_project
  before_action :authorize_plan
  before_action :set_planner_session, except: %i[ new create ]
  rescue_from Planner::StaleRevision, with: :stale_planning_action

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
    if @planner_session.build_as_you_go?
      return render :meal_show unless @planner_session.accepted? || @planner_session.abandoned?
      return redirect_to planner_destination
    end
    redirect_to planner_destination unless @planner_session.asking? || request.headers["Turbo-Frame"].present?
  end

  def answer
    raise ActiveRecord::RecordNotFound if @planner_session.build_as_you_go?
    raise ActiveRecord::RecordNotFound unless @planner_session.asking?

    @planner_session.record_answer!(params.expect(:answer))
    PlannerStepJob.perform_later(@project.id, @planner_session.id, Current.session.id)
    redirect_to project_planner_session_path(@project, @planner_session)
  end

  def voice_session
    raise ActiveRecord::RecordNotFound if @planner_session.build_as_you_go?
    render json: Planner::VoiceSession.new(@planner_session).payload
  rescue Planner::VoiceClientSecretMinter::Error => error
    Rails.error.report(error, handled: true, severity: :warning)
    render json: { error: "Voice planning is unavailable right now. You can keep typing." }, status: :bad_gateway
  end

  def review
    return redirect_to project_planner_session_path(@project, @planner_session) if @planner_session.build_as_you_go?
    raise ActiveRecord::RecordNotFound unless @planner_session.reviewing?
  end

  def skip_to_review
    raise ActiveRecord::RecordNotFound if @planner_session.build_as_you_go?
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
    raise ActiveRecord::RecordNotFound if @planner_session.build_as_you_go?
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
    if @planner_session.build_as_you_go?
      @planner_session.accept_visible!(expected_revision: expected_revision)
      return redirect_to project_path(@project, added_plan: @planner_session.id, anchor: "tool-#{@planner_session.acceptance_tool.tr('_', '-')}"), status: :see_other
    end
    raise ActiveRecord::RecordNotFound unless @planner_session.reviewing?

    @planner_session.accept!(include_proposed: params[:mode] == "all")
    redirect_to @project
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    return planning_error(error) if @planner_session.build_as_you_go?
    redirect_to review_project_planner_session_path(@project, @planner_session), alert: error.message
  end

  def select_answer
    require_build_as_you_go
    # A blank answer is a validation alert from select_answer!, not a 400 the frame cannot show.
    revision = @planner_session.select_answer!(params.fetch(:answer, "").to_s, expected_revision: expected_revision,
      step_index: params[:step_index].presence&.to_i)
    enqueue_generation(revision)
    planning_redirect
  rescue ArgumentError => error
    planning_error(error)
  end

  def continue_planning
    require_build_as_you_go
    @planner_session.continue!(expected_revision: expected_revision)
    planning_redirect
  rescue ArgumentError => error
    planning_error(error)
  end

  def finish_planning
    require_build_as_you_go
    @planner_session.finish_preview!(expected_revision: expected_revision)
    planning_redirect
  rescue ArgumentError => error
    planning_error(error)
  end

  def retry_generation
    require_build_as_you_go
    enqueue_generation(@planner_session.queue_generation!(expected_revision: expected_revision))
    planning_redirect
  rescue ArgumentError => error
    planning_error(error)
  end

  def save_and_leave
    require_build_as_you_go
    redirect_to @project, status: :see_other, notice: "Planning saved. You can continue from this Project."
  end

  def pending_item
    require_build_as_you_go
    item = params.expect(item: [ :id, :decision, :resolution, { fields: [ :label, :date, :time, :capacity, :title, :details, :due_on, :starts_at, :ends_at, :location, :description, :estimated_dollars, :name, :tool, { columns: [ %i[name type] ] } ] } ])
    args = { id: item.fetch(:id), expected_revision: expected_revision }
    case item[:decision]
    when "edit" then @planner_session.edit_pending_item!(**args, fields: item.fetch(:fields).to_h)
    when "remove" then @planner_session.remove_pending_item!(**args)
    when "restore" then @planner_session.restore_pending_item!(**args)
    when "resolve" then @planner_session.resolve_pending_conflict!(**args, choice: item.fetch(:resolution))
    else raise ArgumentError, "Choose an item action."
    end
    planning_redirect
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    planning_error(error)
  end

  def planning_details
    require_build_as_you_go
    details = params.expect(project: [ :name, :starts_on ]).to_h.symbolize_keys
    @planner_session.update_planning_details!(**details, expected_revision: expected_revision)
    planning_redirect
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    planning_error(error)
  end

  private
    def require_build_as_you_go
      raise ActiveRecord::RecordNotFound unless @planner_session.build_as_you_go?
    end

    def expected_revision
      Integer(params.expect(:expected_revision).to_s, 10)
    end

    def enqueue_generation(revision)
      PlannerStepJob.perform_later(@project.id, @planner_session.id, Current.session.id, revision)
    end

    def planning_redirect
      redirect_to project_planner_session_path(@project, @planner_session), status: :see_other
    end

    def planning_error(error)
      redirect_to project_planner_session_path(@project, @planner_session), status: :see_other, alert: error.message
    end

    def stale_planning_action
      planning_error(ArgumentError.new("This plan changed in another request. Your latest plan is shown; please try that change again."))
    end

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
