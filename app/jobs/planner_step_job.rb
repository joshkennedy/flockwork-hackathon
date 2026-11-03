class PlannerStepJob < ApplicationJob
  queue_as :default

  def perform(project_id, planner_session_id, current_session_id, revision = nil)
    current_session = Session.includes(person: :organization).find_by(id: current_session_id)
    unless current_session
      saved_planner = PlannerSession.includes(started_by: :organization).find_by(id: planner_session_id, project_id: project_id)
      return unless saved_planner&.build_as_you_go?
      current_session = Session.new(person: saved_planner.started_by)
    end

    Current.set(session: current_session) do
      project = Current.organization.projects.find(project_id)
      planner_session = project.planner_sessions.find(planner_session_id)
      if planner_session.build_as_you_go?
        return unless revision
        return unless Policy.can?(Current.person, :plan, project)
        stream = Planner::PreviewStream.new(planner_session)
        planner_session.generate!(revision: revision) { |partial| stream.push(partial) }
      else
        planner_session.run_step!
      end
      broadcast(planner_session)
    end
  end

  private
    def broadcast(planner_session)
      if planner_session.build_as_you_go?
        Turbo::StreamsChannel.broadcast_replace_to(
          planner_session,
          target: ActionView::RecordIdentifier.dom_id(planner_session, :meal_builder),
          partial: "planner_sessions/meal_builder",
          locals: { project: planner_session.project, planner_session: }
        )
        return
      end
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
