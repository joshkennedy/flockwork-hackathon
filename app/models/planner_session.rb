class PlannerSession < ApplicationRecord
  ERROR_MESSAGE = "The Planner couldn't reach the AI just now. You can keep building by hand."
  MAX_GENERATED_QUESTIONS = 3
  GENERATION_STATES = %w[idle queued running ready failed].freeze

  belongs_to :project
  belongs_to :started_by, class_name: "Person"

  enum :status, { asking: 0, reviewing: 1, accepted: 2, abandoned: 3 }

  validates :description, presence: true
  PLANNING_KINDS = %w[meal_train retreat workday children_program other].freeze

  validates :flow_version, inclusion: { in: [ 1, 2, 3 ] }
  validates :planning_kind, inclusion: { in: PLANNING_KINDS }
  validates :generation_state, inclusion: { in: GENERATION_STATES }

  def meal_planner?
    flow_version == 2
  end

  def build_as_you_go?
    flow_version.in?([ 2, 3 ])
  end

  def generation_busy?
    generation_state.in?(%w[queued running])
  end

  def generation_stalled?
    generation_busy? && updated_at < 90.seconds.ago
  end

  def ready_to_continue?
    build_as_you_go? && generation_state == "ready" && pending_answer.present?
  end

  def visible_pending_items
    Planner::PendingItems.visible(pending_items)
  end

  def pending_item_count
    visible_pending_items.size
  end

  def pending_item_errors
    visible_pending_items.to_h do |item|
      [ item.fetch("id"), Planner::PendingItems.errors(item, project:) ]
    end.reject { |_, errors| errors.empty? }
  end

  def acceptance_tool
    visible_pending_items.lazy.map { |item| Planner::PendingItems.tool(item) }.find(&:present?)
  end

  def planning_context
    ensure_build_as_you_go!
    {
      "flow_version" => flow_version,
      "planning_kind" => planning_kind,
      "question_limit" => MAX_GENERATED_QUESTIONS,
      "questions_answered" => steps.size,
      "project_intent" => description,
      "answers" => steps.map { |step| step.slice("question", "answer").merge("answer" => private_safe_text(step["answer"])) },
      "pending_answer" => pending_answer&.slice("text", "step_index")&.merge("text" => private_safe_text(pending_answer["text"])),
      "project" => { "name" => project.name, "starts_on" => project.starts_on&.iso8601 },
      "existing_artifacts" => {
        "task_titles" => project.tasks.order(:id).limit(100).pluck(:title),
        "schedule_item_titles" => project.schedule_items.order(:id).limit(100).pluck(:title),
        "slot_labels" => project.slots.order(:id).limit(100).pluck(:label),
        "booking_descriptions" => project.budget_lines.booking.order(:id).limit(100).pluck(:description),
        "purchase_descriptions" => project.budget_lines.purchase.order(:id).limit(100).pluck(:description),
        "list_names" => project.lists.order(:id).limit(100).pluck(:name),
        "enabled_tools" => project.enabled_tools
      },
      "pending_items" => visible_pending_items.map do |item|
        item.slice("source_key", "kind", "fields", "day_offset", "removed", "user_edits", "conflict")
      end
    }
  end

  def update_planning_details!(name: nil, starts_on: nil, expected_revision:)
    with_lock do
      ensure_mutable_build_as_you_go!
      ensure_not_busy!
      raise Planner::StaleRevision unless generation_revision == expected_revision

      old_start = project.starts_on
      new_start = starts_on.present? ? Date.iso8601(starts_on.to_s) : old_start
      project.name = name if name.present?
      if starts_on.present?
        project.ends_on += (new_start - old_start).to_i if old_start && project.ends_on
        project.starts_on = new_start
      end
      project.save!

      if new_start && old_start != new_start
        offset = old_start ? (new_start - old_start).to_i : nil
        self.pending_items = pending_items.map do |item|
          next item unless %w[slot schedule_item task].include?(item["kind"])
          date_field = item["kind"] == "task" ? "due_on" : "date"
          next item if item.fetch("user_edits", {}).key?(date_field)

          date = item.dig("fields", date_field).presence
          next item unless date.present? || item.key?("day_offset")
          next item if old_start.nil? && date.present?
          rebased = if date && offset
            Date.iso8601(date) + offset
          else
            new_start + item.fetch("day_offset", 0).to_i
          end
          item.deep_merge(
            "fields" => { date_field => rebased.iso8601 },
            "suggested_fields" => { date_field => rebased.iso8601 }
          )
        rescue Date::Error, TypeError
          item
        end
      end

      self.generation_revision += 1
      save!
      generation_revision
    end
  end

  def queue_generation!(expected_revision: nil)
    with_lock do
      ensure_mutable_build_as_you_go!
      ensure_not_busy! unless generation_stalled?
      if expected_revision.present? && generation_revision != Integer(expected_revision)
        raise Planner::StaleRevision
      end
      self.generation_revision += 1
      self.generation_state = "queued"
      self.prepared_card = nil
      self.last_error = nil
      save!
      generation_revision
    end
  end

  def generate!(revision:, &on_partial)
    with_lock do
      return false unless generation_revision == revision && generation_state == "queued" && asking?

      update!(generation_state: "running")
    end

    response = Planner::ContextBuilder.new(self).ask(&on_partial)
    apply_generation!(revision:, response:)
  rescue StandardError => error
    with_lock do
      if generation_revision == revision && generation_state == "running" && asking?
        update!(generation_state: "failed", last_error: error.message)
      end
    end
    false
  end

  def select_answer!(text, expected_revision:, step_index: nil)
    with_lock do
      ensure_mutable_build_as_you_go!
      ensure_not_busy!
      raise Planner::StaleRevision unless generation_revision == expected_revision

      index = if step_index.nil?
        pending_answer&.fetch("step_index", nil) || steps.length
      else
        Integer(step_index)
      end
      raise ArgumentError, "Unknown Planner step" unless index.between?(0, steps.length)
      card = index < steps.length ? steps.fetch(index) : current_card&.stringify_keys
      raise ArgumentError, "There is no current Planner card" unless card

      raise ArgumentError, "Answer can't be blank" if text.blank?

      redacted_text = Planner::NameRedactor.new(Current.organization).call(text)
      revised_steps = steps.take(index) + [
        {
          "question" => card.fetch("question"),
          "options" => card.fetch("options", []),
          "answer" => redacted_text
        }
      ]
      self.steps = revised_steps
      self.status = :asking
      self.pending_answer = { "text" => redacted_text, "step_index" => index }
      self.current_card = card.slice("question", "options")
      self.generation_revision += 1
      self.generation_state = "queued"
      self.prepared_card = nil
      self.last_error = nil
      save!
      generation_revision
    end
  end

  def continue!(expected_revision:)
    with_lock do
      ensure_mutable_build_as_you_go!
      raise Planner::StaleRevision unless generation_revision == expected_revision
      raise ArgumentError, "The preview is not ready" unless ready_to_continue?
      self.generation_revision += 1

      if prepared_card.present? && steps.length < MAX_GENERATED_QUESTIONS
        self.current_card = prepared_card
        self.prepared_card = nil
        self.pending_answer = nil
        self.generation_state = "idle"
      else
        self.status = :reviewing
        self.current_card = nil
        self.prepared_card = nil
        self.pending_answer = nil
        self.generation_state = "idle"
      end
      save!
    end
  end

  def finish_preview!(expected_revision:)
    with_lock do
      ensure_mutable_build_as_you_go!
      ensure_not_busy!
      raise Planner::StaleRevision unless generation_revision == expected_revision
      raise ArgumentError, "There is no useful preview" if visible_pending_items.empty?

      update!(
        generation_revision: generation_revision + 1,
        status: :reviewing,
        current_card: nil,
        prepared_card: nil,
        pending_answer: nil,
        generation_state: "idle"
      )
    end
  end

  def edit_pending_item!(id:, fields:, expected_revision:)
    change_pending_item!(id:, expected_revision:) do |item|
      sanitized = Planner::PendingItems.sanitize_fields(item.fetch("kind"), fields)
      item.merge(
        "fields" => item.fetch("fields").merge(sanitized),
        "user_edits" => item.fetch("user_edits", {}).merge(sanitized),
        "conflict" => nil
      )
    end
  end

  def remove_pending_item!(id:, expected_revision:)
    change_pending_item!(id:, expected_revision:) { |item| item.merge("removed" => true, "removed_revision" => generation_revision + 1) }
  end

  def restore_pending_item!(id:, expected_revision:)
    change_pending_item!(id:, expected_revision:) { |item| item.merge("removed" => false) }
  end

  def resolve_pending_conflict!(id:, choice:, expected_revision:)
    change_pending_item!(id:, expected_revision:) do |item|
      conflict = item.fetch("conflict")
      case choice.to_s
      when "keep_edit"
        item.merge("conflict" => nil)
      when "use_suggestion"
        if conflict.fetch("type") == "removed_by_revision"
          next item.merge("removed" => true, "conflict" => nil)
        end
        fields = item.fetch("fields").dup
        user_edits = item.fetch("user_edits", {}).dup
        conflict.fetch("fields", {}).each do |field, values|
          fields[field] = values.fetch("suggested")
          user_edits.delete(field)
        end
        item.merge("fields" => fields, "user_edits" => user_edits, "conflict" => nil)
      else
        raise ArgumentError, "Unknown conflict choice"
      end
    end
  end

  def accept_visible!(expected_revision: nil)
    with_lock do
      ensure_build_as_you_go!
      return acceptance_receipt if accepted?
      raise Planner::StaleRevision if expected_revision && generation_revision != expected_revision
      ensure_not_busy!
      raise ArgumentError, "Finish reviewing before adding pending work" unless reviewing?

      items = visible_pending_items
      raise ArgumentError, "There is no pending work to add" if items.empty?
      raise ArgumentError, "Resolve pending conflicts before adding" if items.any? { |item| item["conflict"].present? }

      errors = pending_item_errors
      if errors.any?
        if meal_planner?
          item = items.find { |candidate| errors.key?(candidate.fetch("id")) }
          fields = item.fetch("fields")
          invalid = Slot.new(project:, label: fields["label"], date: fields["date"], starts_at_time: fields["time"].presence, capacity: fields["capacity"])
          invalid.valid?
          raise ActiveRecord::RecordInvalid, invalid
        end
        raise ArgumentError, errors.values.flatten.to_sentence
      end

      created_ids = Hash.new { |hash, key| hash[key] = [] }
      items.each do |item|
        created = Planner::PendingItems.create!(project, item)
        created_ids[item.fetch("kind")] << created.id if created.respond_to?(:id)
      end
      tools = items.map { |item| Planner::PendingItems.tool(item) }.compact
      project.update!(enabled_tools: project.enabled_tools | tools)
      update!(status: :accepted, accepted_at: Time.current, current_card: nil, prepared_card: nil)
      receipt = acceptance_receipt.merge("created_ids" => created_ids, "acceptance_tool" => acceptance_tool)
      receipt["slot_ids"] = created_ids["slot"] if meal_planner?
      receipt
    end
  end

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
    redacted_text = Planner::NameRedactor.new(Current.organization).call(text)

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
    return update!(status: :abandoned, current_card: nil) unless build_as_you_go?

    with_lock do
      ensure_mutable_build_as_you_go!
      self.generation_revision += 1
      update!(
        status: :abandoned,
        generation_state: "idle",
        current_card: nil,
        prepared_card: nil,
        pending_answer: nil
      )
    end
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
    def private_safe_text(text)
      Planner::NameRedactor.new(Current.organization).call(text.to_s)
    end

    def apply_generation!(revision:, response:)
      response.validate!
      if meal_planner? && (response.added.size > 3 || response.added.any? { |item| item["kind"] != "slot_run" })
        raise ArgumentError, "Expected a meal preview"
      end
      with_lock do
        return false unless generation_revision == revision && generation_state == "running" && asking?

        self.pending_items = Planner::PendingItems.reconcile(
          existing: pending_items,
          added: response.added,
          removed_ids: response.removed_ids,
          project:
        )
        next_card = response.finished || steps.length >= MAX_GENERATED_QUESTIONS ? nil : response.card&.deep_stringify_keys
        if pending_answer.present?
          self.prepared_card = next_card
          self.generation_state = "ready"
        elsif next_card.present?
          self.current_card = next_card
          self.prepared_card = nil
          self.generation_state = "idle"
        else
          self.status = :reviewing
          self.current_card = nil
          self.prepared_card = nil
          self.generation_state = "idle"
        end
        self.last_error = nil
        save!
        true
      end
    end

    def change_pending_item!(id:, expected_revision:)
      with_lock do
        ensure_mutable_build_as_you_go!
        ensure_not_busy!
        raise Planner::StaleRevision unless generation_revision == expected_revision
        found = false
        self.pending_items = pending_items.map do |item|
          next item unless item.fetch("id") == id

          found = true
          yield item
        end
        raise ActiveRecord::RecordNotFound unless found

        self.generation_revision += 1
        save!
        generation_revision
      end
    end

    def acceptance_receipt
      {
        "accepted_at" => accepted_at&.iso8601,
        "item_count" => pending_item_count
      }
    end

    def ensure_build_as_you_go!
      raise ArgumentError, "This operation requires a build-as-you-go Planner session" unless build_as_you_go?
    end

    def ensure_mutable_build_as_you_go!
      ensure_build_as_you_go!
      raise ArgumentError, "Accepted Planner sessions are immutable" if accepted?
    end

    def ensure_not_busy!
      raise ArgumentError, "Generation is still in progress" if generation_busy?
    end

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
