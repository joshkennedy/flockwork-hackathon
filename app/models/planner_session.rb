class PlannerSession < ApplicationRecord
  ERROR_MESSAGE = "The Planner couldn't reach the AI just now. You can keep building by hand."

  belongs_to :project
  belongs_to :started_by, class_name: "Person"

  enum :status, { asking: 0, reviewing: 1, accepted: 2, abandoned: 3 }

  validates :description, presence: true

  def start!
    request_next_response
  end

  def answer!(text)
    card = current_card&.stringify_keys
    raise ArgumentError, "There is no current Planner card" unless card

    update!(
      steps: steps + [
        {
          "question" => card.fetch("question"),
          "options" => card.fetch("options"),
          "answer" => text
        }
      ]
    )
    request_next_response
  end

  def skip_to_review!
    update!(status: :reviewing, current_card: nil)
  end

  def abandon!
    update!(status: :abandoned, current_card: nil)
  end

  def decide_suggestion!(id:, decision:, title: nil, details: nil)
    found = false
    updated = suggestions.map do |suggestion|
      next suggestion unless suggestion.fetch("id") == id

      found = true
      case decision
      when "keep", "drop"
        suggestion.merge("status" => decision == "keep" ? "kept" : "dropped")
      when "edit"
        fields = suggestion.fetch("fields").merge("title" => title, "details" => details)
        suggestion.merge("fields" => fields, "status" => "edited")
      else
        raise ArgumentError, "Unknown Suggestion decision"
      end
    end
    raise ActiveRecord::RecordNotFound unless found

    update!(suggestions: updated)
  end

  def accept!(include_proposed:)
    transaction do
      suggestions.filter do |suggestion|
        %w[kept edited].include?(suggestion.fetch("status")) ||
          (include_proposed && suggestion.fetch("status") == "proposed")
      end.each do |suggestion|
        create_task!(suggestion)
      end

      final_suggestions = if include_proposed
        suggestions.map do |suggestion|
          suggestion["status"] == "proposed" ? suggestion.merge("status" => "kept") : suggestion
        end
      else
        suggestions
      end
      update!(status: :accepted, suggestions: final_suggestions, current_card: nil)
    end
  end

  private
    def request_next_response
      response = begin
        Planner::ContextBuilder.new(self).ask
      rescue StandardError => error
        update!(last_error: error.message)
        return false
      end

      apply_response!(response)
      true
    end

    def apply_response!(response)
      previous_statuses = suggestions.to_h { |suggestion| [ suggestion.fetch("id"), suggestion.fetch("status") ] }
      next_suggestions = response.suggestions.map do |suggestion|
        suggestion = suggestion.deep_stringify_keys
        previous_status = previous_statuses[suggestion.fetch("id")]
        previous_status ? suggestion.merge("status" => previous_status) : suggestion
      end

      if response.finished
        update!(status: :reviewing, current_card: nil, suggestions: next_suggestions, last_error: nil)
      else
        update!(
          status: :asking,
          current_card: response.card.deep_stringify_keys,
          suggestions: next_suggestions,
          last_error: nil
        )
      end
    end

    def create_task!(suggestion)
      raise ArgumentError, "Unsupported Suggestion kind" unless suggestion.fetch("kind") == "task"

      fields = suggestion.fetch("fields")
      due_in_days = fields["due_in_days"]
      due_on = project.starts_on + due_in_days if project.starts_on && due_in_days
      project.tasks.create!(
        title: fields.fetch("title"),
        details: fields.fetch("details"),
        due_on:
      )
    end
end
