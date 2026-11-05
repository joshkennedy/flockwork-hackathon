class PlannerStreamChannel < Turbo::StreamsChannel
  def subscribed
    stream_name = verified_stream_name_from_params
    planner_session = authorized_planner_session
    expected_stream_name = Turbo::StreamsChannel.verified_stream_name(
      Turbo::StreamsChannel.signed_stream_name(planner_session)
    ) if planner_session

    if stream_name.present? && expected_stream_name.present? &&
        ActiveSupport::SecurityUtils.secure_compare(stream_name, expected_stream_name)
      stream_from stream_name
    else
      reject
    end
  end

  private
    def authorized_planner_session
      person = current_person.reload
      project = person.organization.projects
        .joins(:planner_sessions)
        .find_by(planner_sessions: { id: params[:planner_session_id] })
      return unless project && Policy.can?(person, :plan, project)

      project.planner_sessions.find_by(id: params[:planner_session_id])
    rescue ActiveRecord::RecordNotFound
      nil
    end
end
