module Planner
  class ContextBuilder
    def initialize(session)
      @session = session
    end

    def ask
      Rails.configuration.x.planner_provider.call(context)
    end

    private
      attr_reader :session

      def context
        project_name, project_description, enabled_tools = current_project_values

        {
          project_name:,
          project_description:,
          leader_description: session.description,
          answers: session.steps.map { |step| answer_from(step) },
          enabled_tools:,
          existing_task_titles: current_task_titles,
          past_projects: past_projects,
          current_suggestions: safe_suggestions
        }
      end

      def current_project_values
        Current.workspace.projects.where(id: session.project_id).pick(:name, :description, :enabled_tools) ||
          raise(ActiveRecord::RecordNotFound)
      end

      def answer_from(step)
        step = step.stringify_keys
        { question: step.fetch("question"), answer: step.fetch("answer") }
      end

      def current_task_titles
        Current.workspace.tasks.where(project_id: session.project_id).order(:id).pluck(:title)
      end

      def past_projects
        Current.workspace.projects.where.not(id: session.project_id)
          .order(created_at: :desc, id: :desc)
          .limit(5)
          .pluck(:id, :enabled_tools)
          .map do |project_id, tool_mix|
            task_titles = Current.workspace.tasks.where(project_id:).order(:id).pluck(:title)
            { tool_mix:, task_count: task_titles.length, task_titles: }
          end
      end

      def safe_suggestions
        session.suggestions.map do |suggestion|
          suggestion = suggestion.stringify_keys
          fields = suggestion.fetch("fields", {}).stringify_keys.slice("title", "details", "due_in_days", "role")
          {
            id: suggestion.fetch("id"),
            kind: suggestion.fetch("kind"),
            fields:,
            status: suggestion.fetch("status")
          }
        end
      end
  end
end
