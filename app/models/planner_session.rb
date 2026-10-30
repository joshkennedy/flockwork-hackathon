class PlannerSession < ApplicationRecord
  ERROR_MESSAGE = "The Planner couldn't reach the AI just now. You can keep building by hand."

  belongs_to :project
  belongs_to :started_by, class_name: "Person"

  enum :status, { asking: 0, reviewing: 1, accepted: 2, abandoned: 3 }

  validates :description, presence: true

  def start!
    run_step!
  end

  def answer!(text)
    record_answer!(text)
    run_step!
  end

  def record_answer!(text)
    card = current_card&.stringify_keys
    raise ArgumentError, "There is no current Planner card" unless card
    redacted_text = Planner::NameRedactor.new(Current.workspace).call(text)

    update!(
      steps: steps + [
        {
          "question" => card.fetch("question"),
          "options" => card.fetch("options"),
          "answer" => redacted_text
        }
      ],
      current_card: nil,
      last_error: nil
    )
  end

  def run_step!
    request_next_response
  end

  def skip_to_review!
    update!(status: :reviewing, current_card: nil)
  end

  def abandon!
    update!(status: :abandoned, current_card: nil)
  end

  def decide_suggestion!(id:, decision:, fields: nil, title: nil, details: nil)
    found = false
    updated = suggestions.map do |suggestion|
      next suggestion unless suggestion.fetch("id") == id

      found = true
      case decision
      when "keep", "drop"
        suggestion.merge("status" => decision == "keep" ? "kept" : "dropped")
      when "edit"
        edited_fields = fields || { "title" => title, "details" => details }.compact
        edited_fields = Planner::SuggestionKinds.sanitize_fields(suggestion.fetch("kind"), edited_fields)
        suggestion.merge(
          "fields" => suggestion.fetch("fields").merge(edited_fields),
          "status" => "edited"
        )
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
        Planner::SuggestionKinds.create!(project, suggestion)
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
        reload
        update!(last_error: error.message) if asking?
        return false
      end

      apply_response!(response)
      true
    end

    def apply_response!(response)
      reload
      return unless asking?

      next_suggestions = suggestions.reject do |suggestion|
        response.removed_ids.include?(suggestion.fetch("id")) &&
          !%w[kept edited].include?(suggestion.fetch("status"))
      end
      response.added.each do |added|
        added = added.deep_stringify_keys
        kind = added["kind"]
        next unless Planner::SuggestionKinds::KINDS.key?(kind)

        next_suggestions << {
          "id" => SecureRandom.uuid,
          "kind" => kind,
          "fields" => Planner::SuggestionKinds.sanitize_fields(kind, added.fetch("fields", {})),
          "status" => "proposed"
        }
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
end
