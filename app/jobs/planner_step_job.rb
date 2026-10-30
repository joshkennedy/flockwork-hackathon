class PlannerStepJob < ApplicationJob
  queue_as :default

  def perform(project_id, planner_session_id, current_session_id)
    current_session = Session.includes(person: :workspace).find(current_session_id)

    Current.set(session: current_session) do
      project = Current.workspace.projects.find(project_id)
      planner_session = project.planner_sessions.find(planner_session_id)
      planner_session.run_step!
      broadcast(planner_session)
    end
  end

  private
    def broadcast(planner_session)
      Turbo::StreamsChannel.broadcast_replace_to(
        planner_session,
        target: ActionView::RecordIdentifier.dom_id(planner_session, :card),
        partial: "planner_sessions/card",
        locals: { project: planner_session.project, planner_session: }
      )
      Turbo::StreamsChannel.broadcast_replace_to(
        planner_session,
        target: ActionView::RecordIdentifier.dom_id(planner_session, :summary),
        partial: "planner_sessions/summary",
        locals: { planner_session: }
      )
    end
end
