class PlannerStreamChannel < Turbo::StreamsChannel
  class << self
    def authorized_stream_name(planner_session)
      "#{stream_name_from([ planner_session ])}:authorized"
    end

    def broadcast_replace_to(planner_session, **options)
      super(authorized_stream_name(planner_session), **options)
    end
  end

  def subscribed
    stream_name = verified_stream_name_from_params
    planner_session = authorized_planner_session
    expected_stream_name = Turbo::StreamsChannel.verified_stream_name(
      Turbo::StreamsChannel.signed_stream_name(planner_session)
    ) if planner_session

    if stream_name.present? && expected_stream_name.present? &&
        ActiveSupport::SecurityUtils.secure_compare(stream_name, expected_stream_name)
      stream_from self.class.authorized_stream_name(planner_session), coder: ActiveSupport::JSON do |message|
        transmit(message) if authorized_planner_session
      end
    else
      reject
    end
  end

  private
    def authorized_planner_session
      person = current_session.person.reload
      project = person.organization.projects
        .joins(:planner_sessions)
        .find_by(planner_sessions: { id: params[:planner_session_id] })
      return unless project && Policy.can?(person, :plan, project)

      project.planner_sessions.find_by(id: params[:planner_session_id])
    rescue ActiveRecord::RecordNotFound
      nil
    end
end
