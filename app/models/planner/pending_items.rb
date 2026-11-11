module Planner
  module PendingItems
    SLOT_KIND = "slot"
    SLOT_RUN_KIND = "slot_run"
    KINDS = Planner::SuggestionKinds::KINDS.keys.freeze
    EDITABLE = {
      "shift_project_dates" => %w[days],
      "slot" => %w[label date time capacity schedule_item_source_key], "task" => %w[title details due_on],
      "schedule_item" => %w[title date starts_at ends_at location],
      "booking" => %w[description estimated_dollars], "purchase" => %w[description estimated_dollars],
      "list" => %w[name columns], "enable_tool" => %w[tool], "skill" => %w[name]
    }.freeze
    SOURCE_KEY = /\A[a-zA-Z0-9_-]{1,80}\z/

    Candidate = Data.define(:kind, :source_key, :fields, :metadata) do
      def to_h
        { "id" => Planner::PendingItems.stable_id(source_key), "source_key" => source_key, "kind" => kind,
          "fields" => fields, "suggested_fields" => fields, "removed" => false, "user_edits" => {}, "conflict" => nil }.merge(metadata)
      end
    end

    module_function

    # Model responses are deltas: an item the model leaves out of `added` stays, and only
    # `removed_ids` removes saved draft work.
    def reconcile(existing:, added:, removed_ids:, project:, revision: nil)
      validate_snapshot!(added, existing:, project:)
      incoming = expand(added, project:)
      raise ArgumentError, "Planner preview is too large" if incoming.size > 200
      existing_ids = existing.to_set { |item| item.fetch("id") }
      incoming_by_key = incoming.index_by(&:source_key)
      result = existing.map do |item|
        candidate = incoming_by_key.delete(item.fetch("source_key"))
        candidate ? merge(item, candidate) : item
      end
      result.concat(incoming.filter_map { |candidate| candidate.to_h if incoming_by_key.key?(candidate.source_key) })
      result = result.filter_map do |item|
        next item unless removed_ids.include?(item.fetch("id"))
        next unless preserved_by_leader?(item)

        item.merge("conflict" => { "type" => "removed_by_revision", "suggested_fields" => nil })
      end
      raise ArgumentError, "Planner preview is too large" if result.size > 200
      unless revision.nil?
        result = result.map do |item|
          existing_ids.include?(item.fetch("id")) ? item : item.merge("added_revision" => revision)
        end
      end

      result
    end

    # Meal setup builds the whole plan itself, so `incoming` is a full snapshot: anything
    # missing from it is gone, unless the Leader edited it.
    def reconcile_candidates(existing:, incoming:, removed_ids: [])
      prior = existing.index_by { |item| item.fetch("source_key") }
      raise ArgumentError, "Planner preview is too large" if incoming.size > 200
      keys = incoming.to_set(&:source_key)
      result = incoming.map { |candidate| prior[candidate.source_key] ? merge(prior[candidate.source_key], candidate) : candidate.to_h }
      existing.each do |item|
        next if keys.include?(item.fetch("source_key")) || !preserved_by_leader?(item)
        result << item.merge("conflict" => { "type" => "removed_by_revision", "suggested_fields" => nil })
      end
      result.reject { |item| removed_ids.include?(item.fetch("id")) && !preserved_by_leader?(item) }
    end

    def expand(added, project:)
      added.flat_map.with_index do |raw, index|
        item = raw.deep_stringify_keys
        if item.fetch("kind") == SLOT_RUN_KIND
          expand_slot_run(item, project:, source_index: index)
        else
          kind = item.fetch("kind")
          fields, metadata = normalize_provider_fields(kind, item.fetch("fields"), project:)
          [ candidate(kind:, source_key: item.fetch("source_key"), fields:, metadata:) ]
        end
      end
    end

    def visible(items) = items.reject { |item| item["removed"] }

    def rebase_dates(items, from:, to:)
      offset = from ? (to - from).to_i : nil
      items.map do |item|
        next item unless %w[slot schedule_item task].include?(item["kind"])
        date_field = item["kind"] == "task" ? "due_on" : "date"
        next item if item.fetch("user_edits", {}).key?(date_field)

        date = item.dig("fields", date_field).presence
        next item unless date.present? || item.key?("day_offset")
        next item if from.nil? && date.present?
        rebased = if date && offset
          Date.iso8601(date) + offset
        else
          to + item.fetch("day_offset", 0).to_i
        end
        item.deep_merge(
          "fields" => { date_field => rebased.iso8601 },
          "suggested_fields" => { date_field => rebased.iso8601 }
        )
      rescue Date::Error, TypeError
        item
      end
    end

    def fields_for(kind)
      definitions = Planner::SuggestionKinds.fields_for(kind == SLOT_KIND ? SLOT_RUN_KIND : kind).slice(*editable_fields(kind))
      definitions = definitions.merge("date" => { label: "Date", input: :date, schema: { type: "string" } }) if %w[slot schedule_item].include?(kind.to_s)
      definitions = definitions.merge("due_on" => { label: "Due date", input: :date, schema: { type: [ "string", "null" ] } }) if kind.to_s == "task"
      definitions
    end
    def existing_schedule_item_source_key(schedule_item) = "existing_schedule_item_#{schedule_item.id}"
    def editable_fields(kind) = EDITABLE.fetch(kind.to_s)
    def tool(item)
      item = item.deep_stringify_keys
      return item.dig("fields", "tool") if item["kind"] == "enable_tool"

      kind = item.fetch("kind")
      Planner::SuggestionKinds::KINDS.dig(kind == SLOT_KIND ? SLOT_RUN_KIND : kind, :tool)
    end
    def summary(item)
      item = item.deep_stringify_keys
      fields = item.fetch("fields")
      case item.fetch("kind")
      when "shift_project_dates" then Planner::SuggestionKinds.summary(item)
      when "slot" then fields["label"]
      when "task", "schedule_item" then fields["title"]
      when "booking", "purchase" then fields["description"]
      when "list" then fields["name"]
      when "enable_tool" then Project::TOOL_LABELS[fields["tool"]] || fields["tool"]
      when "skill" then Skills.label(fields["name"].to_s)
      end
    end

    def validate_snapshot!(added, existing:, project:)
      raise ArgumentError, "Expected a complete Planner preview" unless added.is_a?(Array) && added.size <= 100
      identities = added.map do |raw|
        item = raw.deep_stringify_keys
        kind, key = item["kind"], item["source_key"]
        raise ArgumentError, "Unknown Planner item kind" unless KINDS.include?(kind)
        raise ArgumentError, "Invalid Planner item identity" unless key.is_a?(String) && key.match?(SOURCE_KEY)
        validate_fields!(kind, item["fields"], project:)
        [ key, kind ]
      end
      raise ArgumentError, "Duplicate meal series" unless identities.map(&:first).uniq.size == identities.size
      old = existing.group_by { |item| item.fetch("source_key").sub(/:\d+\z/, "") }
      fresh = identities.to_h
      old.each do |key, items|
        next unless fresh[key]
        old_kind = items.first.fetch("kind") == SLOT_KIND ? SLOT_RUN_KIND : items.first.fetch("kind")
        raise ArgumentError, "Planner item kind changed; the existing preview was preserved" unless old_kind == fresh[key]
      end
      if old.any? && (fresh.keys - old.keys).any? && (old.keys - fresh.keys).any?
        raise ArgumentError, "Meal series identity changed; the existing preview was preserved"
      end
    rescue KeyError, NoMethodError, TypeError, Date::Error
      raise ArgumentError, "Malformed Planner preview"
    end

    def sanitize_fields(kind, fields)
      fields = fields.to_h.deep_stringify_keys
      if kind == SLOT_RUN_KIND
        return fields.slice("label", "start_date", "end_date", "start_day_offset", "end_day_offset", "time", "capacity", "schedule_item_source_key")
      end
      result = fields.slice(*editable_fields(kind))
      %w[date due_on].each { |key| result[key] = Date.iso8601(result[key]).iso8601 if result[key].present? }
      result["capacity"] = Integer(result["capacity"]) if result.key?("capacity")
      if result["columns"].is_a?(Array)
        result["columns"] = result["columns"].map { |column| column.to_h.deep_stringify_keys.slice("name", "type") }
      end
      result
    rescue ArgumentError, TypeError
      result || fields
    end

    def normalize_provider_fields(kind, fields, project:)
      raw = fields.to_h.deep_stringify_keys
      offset = kind == "task" ? raw["due_in_days"] : raw["day_offset"]
      normalized = sanitize_fields(kind, raw)
      date_field = kind == "task" ? "due_on" : (kind == "schedule_item" ? "date" : nil)
      if date_field && normalized[date_field].blank? && offset.is_a?(Integer) && offset.between?(-365, 365)
        normalized[date_field] = (project.starts_on + offset).iso8601 if project.starts_on
      end
      [ normalized, date_field && offset.is_a?(Integer) ? { "day_offset" => offset } : {} ]
    end

    def errors(item, project:)
      item = item.deep_stringify_keys
      fields = item["fields"]
      return [ "Item fields are missing" ] unless fields.is_a?(Hash)
      raw_errors = FieldValidation.errors(item["kind"], fields)
      return raw_errors if raw_errors.any?
      if item["kind"] == "task" && item.key?("day_offset") && fields["due_on"].blank? && !item.fetch("user_edits", {}).key?("due_on")
        return [ "Choose a Project start date or a due date" ]
      end
      record = case item["kind"]
      when "booking", "purchase"
        build_record(project, item)
      when "list"
        return [ "At least one valid column is required" ] unless FieldValidation.valid_columns?(fields["columns"])
        build_record(project, item)
      when "enable_tool" then return Project::TOOLS.include?(fields["tool"]) ? [] : [ "Tool must be one from the list" ]
      when "shift_project_dates"
        ProjectDateShift.days(fields["days"])
        return []
      when "skill" then return Skills.normalize(fields["name"]).one? ? [] : [ "Skill must be one skill name" ]
      else
        build_record(project, item) || (return [ "Unknown item type" ])
      end
      record.valid?
      record.errors.full_messages
    rescue ArgumentError, TypeError
      [ "Some fields on this item are missing or the wrong kind" ]
    end

    def create!(project, item, schedule_item: nil)
      item = item.deep_stringify_keys
      fields = item.fetch("fields")
      case item.fetch("kind")
      when "shift_project_dates" then ProjectDateShift.new(project, days: fields.fetch("days")).call
      when "skill"
        project.update!(skills_needed: project.skills_needed + [ fields["name"] ])
        nil
      else
        association, attributes = record_definition(item, schedule_item:)
        return unless association

        record = project.public_send(association).create!(attributes)
        if item["kind"] == "list"
          fields.fetch("columns").each { |column| record.columns.create!(name: column["name"], column_type: column["type"]) }
        end
        record
      end
    end

    def build_record(project, item, schedule_item: nil)
      association, attributes = record_definition(item, schedule_item:)
      project.public_send(association).klass.new(project:, **attributes) if association
    end

    def record_definition(item, schedule_item: nil)
      fields = item.fetch("fields")
      case item.fetch("kind")
      when "slot" then [ :slots, { label: fields["label"], date: fields["date"], starts_at_time: fields["time"].presence, capacity: fields["capacity"], schedule_item: } ]
      when "task" then [ :tasks, { title: fields["title"], details: fields["details"], due_on: fields["due_on"] } ]
      when "schedule_item" then [ :schedule_items, { title: fields["title"], date: fields["date"], starts_at_time: fields["starts_at"].presence, ends_at_time: fields["ends_at"].presence, location: fields["location"].presence } ]
      when "booking", "purchase" then [ :budget_lines, { kind: item["kind"], description: fields["description"], estimated: fields["estimated_dollars"] } ]
      when "list" then [ :lists, { name: fields["name"] } ]
      end
    end
    private_class_method :record_definition

    def candidate(kind: SLOT_KIND, fields:, source_key:, metadata: {})
      Candidate.new(kind, source_key, fields, metadata)
    end
    def stable_id(key) = Digest::SHA256.hexdigest(key).then { |h| "#{h[0, 8]}-#{h[8, 4]}-4#{h[13, 3]}-8#{h[17, 3]}-#{h[20, 12]}" }
    def source_key(item, index, occurrence) = "#{item['source_key'].presence || "meal-slots-#{index}"}:#{occurrence}"

    def expand_slot_run(item, project:, source_index:)
      fields = item.fetch("fields")
      start = fields["start_date"].present? ? Date.iso8601(fields["start_date"]) : (project.starts_on && project.starts_on + fields.fetch("start_day_offset", 0))
      count = fields["end_date"].present? ? (start ? (Date.iso8601(fields["end_date"]) - start).to_i + 1 : 0) : fields.fetch("end_day_offset", 0) - fields.fetch("start_day_offset", 0) + 1
      return [] unless count.between?(1, 60)
      count.times.map do |index|
        candidate(source_key: source_key(item, source_index, index), fields: sanitize_fields(SLOT_KIND,
          "label" => fields["label"], "date" => start && (start + index).iso8601, "time" => fields["time"], "capacity" => fields.fetch("capacity", 1),
          "schedule_item_source_key" => fields["schedule_item_source_key"]
        ), metadata: { "day_offset" => fields.fetch("start_day_offset", 0) + index })
      end
    end

    def merge(previous, candidate)
      edits = previous.fetch("user_edits", {})
      conflicts = edits.each_with_object({}) do |(field, value), result|
        prior = previous.fetch("suggested_fields", previous.fetch("fields"))[field]
        result[field] = { "edited" => value, "suggested" => candidate.fields[field] } if candidate.fields[field] != value && (candidate.fields[field] != prior || previous.dig("conflict", "fields", field))
      end
      merged = candidate.to_h.merge("id" => previous.fetch("id"), "fields" => candidate.fields.merge(edits), "suggested_fields" => candidate.fields,
        "removed" => previous.fetch("removed", false), "user_edits" => edits, "conflict" => conflicts.presence && { "type" => "field_changes", "fields" => conflicts },
        "removed_revision" => previous["removed_revision"])
      previous.key?("added_revision") ? merged.merge("added_revision" => previous["added_revision"]) : merged
    end

    def validate_fields!(kind, fields, project:)
      raise ArgumentError unless fields.is_a?(Hash) && fields.values.none? { |v| v.is_a?(String) && v.bytesize > 10_000 }
      if kind == SLOT_RUN_KIND
        raise ArgumentError unless fields["label"].is_a?(String) && fields["label"].present? && fields.fetch("capacity", 1).is_a?(Integer) && fields.fetch("capacity", 1).between?(1, 10_000)
        raise ArgumentError unless fields["time"].blank? || fields["time"].is_a?(String) && fields["time"].match?(FieldValidation::TIME)
        reference = fields["schedule_item_source_key"]
        raise ArgumentError unless reference.nil? || reference.is_a?(String) && reference.match?(SOURCE_KEY)
        if fields["start_date"].present?
          raise ArgumentError unless (Date.iso8601(fields.fetch("end_date")) - Date.iso8601(fields["start_date"])).to_i.between?(0, 59)
        else
          first, last = fields.fetch("start_day_offset", 0), fields.fetch("end_day_offset", 0)
          unless first.is_a?(Integer) && last.is_a?(Integer) && first.between?(0, 59) && last.between?(first, 59)
            raise ArgumentError, "Meal offsets must be within 60 days"
          end
        end
      else
        offset_name = kind == "task" ? "due_in_days" : (kind == "schedule_item" ? "day_offset" : nil)
        if offset_name && !fields[offset_name].nil? && !(fields[offset_name].is_a?(Integer) && fields[offset_name].between?(-365, 365))
          raise ArgumentError, "Date offsets must be whole days within a year"
        end
        invalid = FieldValidation.errors(kind, fields)
        raise ArgumentError, invalid.to_sentence if invalid.any?
        normalized, = normalize_provider_fields(kind, fields, project:)
        draft = errors(candidate(kind:, fields: normalized, source_key: "validation").to_h, project:)
        draft -= [ "Date can't be blank" ] if kind == "schedule_item"
        draft -= [ "At least one valid column is required" ] if kind == "list"
        raise ArgumentError, draft.to_sentence if draft.any?
      end
    end

    def preserved_by_leader?(item) = item.fetch("removed", false) || item.fetch("user_edits", {}).present?
  end
end
