class PlannerStepJob < ApplicationJob
  queue_as :default

  def perform(project_id, planner_session_id, current_session_id, enqueuing_person_id, revision = nil)
    saved_planner = PlannerSession.includes(project: :organization).find_by(id: planner_session_id, project_id: project_id)
    return unless saved_planner

    person = saved_planner.project.organization.people.find_by(id: enqueuing_person_id)
    return unless person

    current_session = person.sessions.find_by(id: current_session_id) || Session.new(person:)

    Current.set(session: current_session) do
      project = Current.organization.projects.find(project_id)
      planner_session = project.planner_sessions.find(planner_session_id)
      return unless plan_allowed?(project)

      if planner_session.build_as_you_go?
        return if planner_session.meal_setup?
        return unless revision
        stream = Planner::PreviewStream.new(planner_session, authorized: -> { plan_allowed?(project) })
        planner_session.generate!(revision: revision) { |partial| stream.push(partial) }
      else
        planner_session.run_step!
      end
      return unless plan_allowed?(project)

      broadcast(planner_session)
    end
  end

  private
    def plan_allowed?(project)
      Current.person.reload
      Policy.can?(Current.person, :plan, project)
    rescue ActiveRecord::RecordNotFound
      false
    end

    def broadcast(planner_session)
      if planner_session.build_as_you_go?
        PlannerStreamChannel.broadcast_replace_to(
          planner_session,
          target: ActionView::RecordIdentifier.dom_id(planner_session, :meal_builder),
          partial: "planner_sessions/meal_builder",
          locals: { project: planner_session.project, planner_session: }
        )
        return
      end
      PlannerStreamChannel.broadcast_replace_to(
        planner_session,
        target: ActionView::RecordIdentifier.dom_id(planner_session, :card),
        partial: "planner_sessions/card",
        locals: { project: planner_session.project, planner_session: }
      )
      PlannerStreamChannel.broadcast_replace_to(
        planner_session,
        target: ActionView::RecordIdentifier.dom_id(planner_session, :summary),
        partial: "planner_sessions/summary",
        locals: { planner_session: }
      )
    end
end
