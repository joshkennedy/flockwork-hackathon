module Planner
  class ContextBuilder
    VOICE_GUIDANCE = <<~TEXT.strip.freeze
      You are Flockwork's planning helper. Ask the current question naturally in one or two short sentences, listen, and when the Leader has answered call answer_card with their answer in their words. Never ask for or repeat people's names; plan open roles. Keep it warm and brief.
    TEXT

    def initialize(session)
      @session = session
    end

    def ask(&on_partial)
      Rails.configuration.x.planner_provider.call(context, &on_partial)
    end

    def voice_instructions
      card = session.current_card&.stringify_keys
      current_card = if card
        redact({
          question: card.fetch("question"),
          options: card.fetch("options")
        })
      elsif session.reviewing?
        { state: "The plan is ready for review. Say one warm, short closing line and do not call a tool." }
      else
        { state: "The first question is being prepared. Say one short line about that and do not call a tool." }
      end
      builder_guidance = if session.build_as_you_go?
        "After answer_card, the Project preview updates on screen and the next question follows. Acknowledge the answer in a few words, then wait."
      end

      <<~INSTRUCTIONS
        #{VOICE_GUIDANCE}
        #{builder_guidance}

        Planner context:
        #{JSON.generate(context)}

        Current card:
        #{JSON.generate(current_card)}
      INSTRUCTIONS
    end

    private
      attr_reader :session

      def context
        if session.build_as_you_go?
          payload = session.planning_context.merge("past_projects" => past_projects)
          return redact(payload)
        end
        project_name, project_description, enabled_tools = current_project_values

        payload = {
          project_name:,
          project_description:,
          leader_description: session.description,
          answers: session.steps.map { |step| answer_from(step) },
          enabled_tools:,
          existing_task_titles: current_task_titles,
          existing_schedule_item_titles: current_schedule_item_titles,
          existing_slot_labels: current_slot_labels,
          existing_booking_descriptions: current_budget_descriptions(:booking),
          existing_purchase_descriptions: current_budget_descriptions(:purchase),
          existing_list_names: current_list_names,
          existing_skills_needed: current_project.skills_needed,
          skill_vocabulary: Skills::SUGGESTED,
          past_projects: past_projects,
          current_suggestions: safe_suggestions
        }
        redact(payload)
      end

      def redact(payload)
        redactor = Planner::NameRedactor.new(Current.organization)
        payload.deep_transform_values { |value| value.is_a?(String) ? redactor.call(value) : value }
      end

      def current_project_values
        current_project.attributes.values_at("name", "description", "enabled_tools")
      end

      def answer_from(step)
        step = step.stringify_keys
        { question: step.fetch("question"), answer: step.fetch("answer") }
      end

      def current_task_titles
        current_project.tasks.order(:id).pluck(:title)
      end

      def current_schedule_item_titles
        current_project.schedule_items.order(:id).pluck(:title)
      end

      def current_slot_labels
        current_project.slots.order(:id).pluck(:label)
      end

      def current_budget_descriptions(kind)
        current_project.budget_lines.public_send(kind).order(:id).pluck(:description)
      end

      def current_list_names
        current_project.lists.order(:id).pluck(:name)
      end

      def past_projects
        projects = Policy.visible_projects(Current.person).where.not(id: session.project_id)
        projects = projects.where(id: Current.person.memberships.leader.select(:project_id)) unless Current.person.admin?
        projects.includes(:tasks, :budget_lines, :project_debrief)
          .order(created_at: :desc, id: :desc)
          .limit(5)
          .map do |project|
            task_titles = project.tasks.sort_by(&:id).map(&:title)
            booking_descriptions = project.budget_lines.select(&:booking?).sort_by(&:id).map(&:description)
            purchase_descriptions = project.budget_lines.select(&:purchase?).sort_by(&:id).map(&:description)
            {
              tool_mix: project.enabled_tools,
              task_count: task_titles.length,
              task_titles:,
              booking_count: booking_descriptions.length,
              booking_descriptions:,
              purchase_count: purchase_descriptions.length,
              purchase_descriptions:
            }.tap do |facts|
              if project.done_at? && project.project_debrief
                redactor = Planner::NameRedactor.new(Current.organization)
                facts[:debrief] = {
                  what_worked: redactor.call(project.project_debrief.what_worked),
                  change_next_time: redactor.call(project.project_debrief.change_next_time)
                }
              end
            end
          end
      end

      def current_project
        @current_project ||= Current.organization.projects.find(session.project_id)
      end

      def safe_suggestions
        session.suggestions.map do |suggestion|
          suggestion = suggestion.stringify_keys
          {
            id: suggestion.fetch("id"),
            kind: suggestion.fetch("kind"),
            fields: Planner::SuggestionKinds.sanitize_fields(
              suggestion.fetch("kind"),
              suggestion.fetch("fields", {})
            ),
            status: suggestion.fetch("status")
          }
        end
      end
  end
end
