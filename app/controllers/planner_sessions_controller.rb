class PlannerSessionsController < ApplicationController
  before_action :set_project
  before_action :authorize_plan
  before_action :set_planner_session, except: %i[ new create ]
  rescue_from Planner::StaleRevision, with: :stale_planning_action
  rate_limit to: 10, within: 1.hour, by: -> { Current.person.id }, name: "planner_spend", scope: :planner,
    only: %i[ create retry_generation ], with: :planner_create_rate_limited
  rate_limit to: 10, within: 1.hour, by: -> { Current.person.id }, name: "voice_session",
    only: :voice_session, with: :voice_session_rate_limited
  rate_limit to: 60, within: 1.hour, by: -> { Current.person.id }, name: "planner_steps",
    only: %i[ answer select_answer ], with: :planner_create_rate_limited

  def new
    @planner_session = @project.planner_sessions.build
  end

  def create
    @planner_session = @project.planner_sessions.build(
      planner_session_params.merge(started_by: Current.person)
    )

    if @planner_session.save
      @planner_session.run_step!
      redirect_to planner_destination
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @planner_session.upgrade_meal_setup! if @planner_session.flow_version == 2
    if @planner_session.meal_setup?
      return redirect_to planner_destination if @planner_session.accepted? || @planner_session.abandoned?
      return render :meal_setup_show
    end
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
    PlannerStepJob.perform_later(@project.id, @planner_session.id, Current.session.id, Current.person.id)
    redirect_to project_planner_session_path(@project, @planner_session)
  end

  def voice_session
    raise ActiveRecord::RecordNotFound if @planner_session.meal_setup?
    render json: Planner::VoiceSession.new(@planner_session).payload
  rescue Planner::VoiceClientSecretMinter::Error => error
    Rails.error.report(error, handled: true, severity: :warning)
    render json: { error: "Voice planning is unavailable right now. You can keep typing." }, status: :bad_gateway
  end

  def voice_instructions
    raise ActiveRecord::RecordNotFound if @planner_session.meal_setup?
    render json: Planner::VoiceSession.new(@planner_session).refresh_payload
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
    return accept_meal_setup if @planner_session.meal_setup?
    if @planner_session.build_as_you_go?
      @planner_session.accept_visible!(
        expected_revision: expected_revision,
        project_name: params.dig(:project, :name)
      )
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
    raise ActiveRecord::RecordNotFound if @planner_session.meal_setup?
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
    raise ActiveRecord::RecordNotFound if @planner_session.meal_setup?
    @planner_session.continue!(expected_revision: expected_revision)
    planning_redirect
  rescue ArgumentError => error
    planning_error(error)
  end

  def finish_planning
    require_build_as_you_go
    raise ActiveRecord::RecordNotFound if @planner_session.meal_setup?
    @planner_session.finish_preview!(expected_revision: expected_revision)
    planning_redirect
  rescue ArgumentError => error
    planning_error(error)
  end

  def retry_generation
    require_build_as_you_go
    raise ActiveRecord::RecordNotFound if @planner_session.meal_setup?
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
    raise ActiveRecord::RecordNotFound if @planner_session.meal_setup?
    details = params.expect(project: [ :name, :starts_on ]).to_h.symbolize_keys
    @planner_session.update_planning_details!(**details, expected_revision: expected_revision)
    planning_redirect
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    planning_error(error)
  end

  def meal_setup
    raise ActiveRecord::RecordNotFound unless @planner_session.meal_setup?

    @planner_session.save_meal_setup!(meal_setup_params, expected_revision: expected_revision)
    plan = MealTrainPlan.from_session(@planner_session)
    render json: {
      revision: @planner_session.generation_revision,
      count: @planner_session.pending_item_count,
      addable: plan.complete? && @planner_session.pending_item_errors.empty? &&
        @planner_session.visible_pending_items.any? && @planner_session.visible_pending_items.none? { |item| item["conflict"].present? },
      preview: render_to_string(partial: "planner_sessions/meal_setup_preview", formats: [ :html ],
        locals: { project: @project, planner_session: @planner_session, plan: })
    }
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    render json: { error: error.message }, status: :unprocessable_content
  end

  private
    def planner_create_rate_limited
      redirect_back fallback_location: new_project_planner_session_path(@project),
        alert: "Too many planning requests. Try again in an hour.", status: :see_other
    end

    def voice_session_rate_limited
      render json: { error: "Too many voice requests. Try again in an hour." }, status: :too_many_requests
    end

    def meal_setup_params
      params.expect(meal_setup: %i[name label start_date days every time capacity]).to_h
    end

    def accept_meal_setup
      preview = params[:preview].present?
      submitted = MealTrainPlan.new(meal_setup_params)
      # Without autosave, changed fields need a fresh preview so the Add count stays truthful.
      preview ||= !@planner_session.accepted? && submitted.complete? && submitted.attributes != @planner_session.meal_setup
      @planner_session.save_meal_setup!(meal_setup_params, expected_revision: expected_revision, accept: !preview)
      return planning_redirect if preview

      redirect_to project_path(@project, added_plan: @planner_session.id, anchor: "tool-signup-sheet"), status: :see_other
    rescue ArgumentError, ActiveRecord::RecordInvalid => error
      @planner_session.reload
      @project.reload
      @meal_setup = MealTrainPlan.new(meal_setup_params)
      flash.now[:alert] = error.message
      render :meal_setup_show, status: :unprocessable_content
    end

    def require_build_as_you_go
      raise ActiveRecord::RecordNotFound unless @planner_session.build_as_you_go?
    end

    def expected_revision
      Integer(params.expect(:expected_revision).to_s, 10)
    end

    def enqueue_generation(revision)
      PlannerStepJob.perform_later(@project.id, @planner_session.id, Current.session.id, Current.person.id, revision)
    end

    def planning_redirect
      redirect_to project_planner_session_path(@project, @planner_session), status: :see_other
    end

    def planning_error(error)
      redirect_to project_planner_session_path(@project, @planner_session), status: :see_other, alert: error.message
    end

    def stale_planning_action
      if request.format.json?
        return render json: { error: "This setup changed in another tab. Reload the saved setup before editing." }, status: :conflict
      end
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
