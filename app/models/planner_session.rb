class PlannerSession < ApplicationRecord
  ERROR_MESSAGE = "The Planner is paused. You can keep going by hand."
  MAX_GENERATED_QUESTIONS = 3
  GENERATION_STATES = %w[idle queued running failed].freeze

  belongs_to :project
  belongs_to :started_by, class_name: "Person"

  enum :status, { asking: 0, reviewing: 1, accepted: 2, abandoned: 3 }

  validates :description, presence: true
  PLANNING_KINDS = Planner::ProjectKinds::CHOICES.keys.freeze

  validates :flow_version, inclusion: { in: [ 1, 2, 3, 4 ] }
  validates :planning_kind, inclusion: { in: PLANNING_KINDS }
  validates :generation_state, inclusion: { in: GENERATION_STATES }

  def meal_planner?
    flow_version.in?([ 2, 4 ])
  end

  def meal_setup?
    flow_version == 4
  end

  def build_as_you_go?
    flow_version.in?([ 2, 3, 4 ])
  end

  def upgrade_meal_setup!
    with_lock do
      return if flow_version != 2 || accepted? || abandoned?

      update!(flow_version: 4, meal_setup: MealTrainPlan.from_session(self).attributes,
        generation_revision: generation_revision + 1, generation_state: "idle", status: :reviewing,
        current_card: nil, prepared_card: nil, pending_answer: nil, last_error: nil)
    end
  end

  def save_meal_setup!(attributes, expected_revision:, accept: false)
    with_lock do
      raise ArgumentError, "This is not a meal setup" unless meal_setup?
      return acceptance_receipt if accept && accepted?
      ensure_mutable_build_as_you_go!
      raise ArgumentError, "This meal setup is closed" unless asking? || reviewing?
      raise Planner::StaleRevision unless generation_revision == expected_revision

      plan = MealTrainPlan.new(attributes)
      raise ArgumentError, plan.errors.full_messages.to_sentence unless plan.valid?(accept ? :complete : :draft)

      if plan.valid?(:schedule) && meal_setup.except("name") != plan.attributes.except("name")
        series_key = pending_items.first&.fetch("source_key")&.sub(/:\d+\z/, "") || "meal-slots"
        self.pending_items = Planner::PendingItems.reconcile_candidates(existing: pending_items, incoming: plan.candidates(series_key:))
      end
      self.meal_setup = plan.attributes
      self.generation_revision += 1
      self.status = :reviewing
      project.update!(name: plan.name) if plan.name.present?
      if accept
        dates = visible_pending_items.map { |item| Date.iso8601(item.dig("fields", "date")) }
        project.update!(starts_on: dates.min, ends_on: dates.max)
      end
      save!
      accept ? accept_visible!(expected_revision: generation_revision) : generation_revision
    end
  end

  def generation_busy?
    generation_state.in?(%w[queued running])
  end

  def generation_stalled?
    generation_busy? && updated_at < 90.seconds.ago
  end

  def visible_pending_items
    Planner::PendingItems.visible(pending_items)
  end

  def recently_added_items
    visible = visible_pending_items
    latest_revision = visible.filter_map { |item| item["added_revision"] }.max
    return [] if latest_revision.nil?

    visible.select { |item| item["added_revision"] == latest_revision }
  end

  def pending_item_count
    visible_pending_items.size
  end

  def pending_item_errors
    items = visible_pending_items
    schedule_references = items.filter_map { |item| item.fetch("source_key") if item["kind"] == "schedule_item" }.to_set
    project.schedule_items.find_each do |schedule_item|
      schedule_references << Planner::PendingItems.existing_schedule_item_source_key(schedule_item)
    end

    items.to_h do |item|
      errors = Planner::PendingItems.errors(item, project:)
      reference = item.dig("fields", "schedule_item_source_key")
      if item["kind"] == "slot" && reference.present? && !schedule_references.include?(reference)
        errors << "Session does not match a planned or existing Schedule item"
      end
      [ item.fetch("id"), errors ]
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
        "schedule_items" => project.schedule_items.chronological.limit(100).map do |schedule_item|
          {
            "source_key" => Planner::PendingItems.existing_schedule_item_source_key(schedule_item),
            "title" => schedule_item.title,
            "date" => schedule_item.date.iso8601
          }
        end,
        "slot_labels" => project.slots.order(:id).limit(100).pluck(:label),
        "booking_descriptions" => project.budget_lines.booking.order(:id).limit(100).pluck(:description),
        "purchase_descriptions" => project.budget_lines.purchase.order(:id).limit(100).pluck(:description),
        "list_names" => project.lists.order(:id).limit(100).pluck(:name),
        "enabled_tools" => project.enabled_tools,
        "skills_needed" => project.skills_needed
      },
      # The seeded vocabulary only; People's own skill tags never reach the model (ADR 0002).
      "skill_vocabulary" => Skills::SUGGESTED,
      "pending_items" => visible_pending_items.map do |item|
        item.slice("id", "source_key", "kind", "fields", "day_offset", "removed", "user_edits", "conflict")
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
        self.pending_items = Planner::PendingItems.rebase_dates(pending_items, from: old_start, to: new_start)
      end

      self.generation_revision += 1
      save!
      generation_revision
    end
  end

  def queue_generation!(expected_revision: nil)
    with_lock do
      raise ArgumentError, "Meal setup does not use generation" if meal_setup?
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
    return false if meal_setup?
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

      raise ArgumentError, "Enter an answer." if text.blank?

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

  def finish_preview!(expected_revision:)
    with_lock do
      ensure_mutable_build_as_you_go!
      ensure_not_busy!
      raise Planner::StaleRevision unless generation_revision == expected_revision
      raise ArgumentError, "There’s nothing to review yet. Answer a question first." if visible_pending_items.empty?

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
      if meal_setup?
        sanitized["time"] = sanitized["time"].presence if sanitized.key?("time")
        sanitized = sanitized.reject { |field, value| item.fetch("fields")[field] == value }
      end
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

  def accept_visible!(expected_revision: nil, project_name: nil)
    with_lock do
      ensure_build_as_you_go!
      return acceptance_receipt if accepted?
      raise Planner::StaleRevision if expected_revision && generation_revision != expected_revision
      ensure_not_busy!
      raise ArgumentError, "Review the Suggestions before adding them." unless reviewing?

      items = visible_pending_items
      raise ArgumentError, "There’s nothing to add yet. Keep at least one Suggestion." if items.empty?
      raise ArgumentError, "Choose which version to keep on each flagged item, then add." if items.any? { |item| item["conflict"].present? }

      errors = pending_item_errors
      if errors.any?
        if meal_planner?
          item = items.find { |candidate| errors.key?(candidate.fetch("id")) }
          invalid = Planner::PendingItems.build_record(project, item)
          invalid.valid?
          raise ActiveRecord::RecordInvalid, invalid
        end
        raise ArgumentError, errors.values.flatten.to_sentence
      end

      project.name = project_name unless project_name.nil?
      project.save!

      created_ids = Hash.new { |hash, key| hash[key] = [] }
      created_schedule_items = {}
      items.sort_by { |item| acceptance_order(item) }.each do |item|
        schedule_item = linked_schedule_item(item, created_schedule_items)
        created = Planner::PendingItems.create!(project, item, schedule_item:)
        created_schedule_items[item.fetch("source_key")] = created if item["kind"] == "schedule_item"
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
        raise ArgumentError, "Choose a Tool from the list." if edited_fields.key?("tool") && Project::TOOLS.exclude?(edited_fields["tool"])
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
    with_lock do
      return if accepted?
      raise ArgumentError, "Review the Suggestions before adding them." unless reviewing?

      suggestions.filter do |suggestion|
        %w[kept edited].include?(suggestion.fetch("status")) ||
          (include_proposed && suggestion.fetch("status") == "proposed")
      end.sort_by { |suggestion| suggestion["kind"] == "shift_project_dates" ? 0 : 1 }.each do |suggestion|
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

    def acceptance_order(item)
      return 0 if item["kind"] == "shift_project_dates"
      return 1 if item["kind"] == "schedule_item"

      2
    end

    def linked_schedule_item(item, created_schedule_items)
      return unless item["kind"] == "slot"

      reference = item.dig("fields", "schedule_item_source_key")
      return if reference.blank?

      if (match = reference.match(/\Aexisting_schedule_item_(\d+)\z/))
        project.schedule_items.find(match[1])
      else
        created_schedule_items.fetch(reference)
      end
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
          project:,
          revision: generation_revision
        )
        next_card = response.finished || steps.length >= MAX_GENERATED_QUESTIONS ? nil : response.card&.deep_stringify_keys
        # The chosen answer advances as soon as its preview is ready; Back to Earlier Choices revisits it.
        self.pending_answer = nil
        self.prepared_card = nil
        self.generation_state = "idle"
        if next_card.present?
          self.current_card = next_card
        else
          self.status = :reviewing
          self.current_card = nil
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
      raise ArgumentError, "This plan is already added to the Project. Start a new plan to change it." if accepted?
    end

    def ensure_not_busy!
      raise ArgumentError, "The Planner is still working. Wait a moment and try again." if generation_busy?
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
        next if kind == "enable_tool" && Project::TOOLS.exclude?(added.dig("fields", "tool"))

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
