module Planner
  module PendingItems
    SLOT_KIND = "slot"
    SLOT_RUN_KIND = "slot_run"
    EDITABLE_SLOT_FIELDS = %w[label date time capacity].freeze

    module_function

    def reconcile(existing:, added:, removed_ids:, project:)
      validate_snapshot!(added, existing:)
      existing_by_key = existing.index_by { |item| item.fetch("source_key") }
      incoming = expand(added, project:)
      incoming_keys = incoming.to_set(&:source_key)

      reconciled = incoming.map do |candidate|
        previous = existing_by_key[candidate.source_key]
        previous ? merge(previous, candidate) : candidate.to_h
      end

      existing.each do |item|
        next if incoming_keys.include?(item.fetch("source_key"))
        next unless preserved_by_leader?(item)

        reconciled << item.merge("conflict" => {
          "type" => "removed_by_revision",
          "suggested_fields" => nil
        })
      end

      reconciled.reject do |item|
        removed_ids.include?(item.fetch("id")) && !preserved_by_leader?(item)
      end
    end

    def expand(added, project:)
      added.flat_map.with_index do |raw, source_index|
        suggestion = raw.deep_stringify_keys
        case suggestion.fetch("kind")
        when SLOT_KIND
          fields = sanitize_slot_fields(suggestion.fetch("fields"))
          [ candidate(fields:, source_key: source_key(suggestion, source_index, 0)) ]
        when SLOT_RUN_KIND
          expand_slot_run(suggestion, project:, source_index:)
        else
          []
        end
      end
    end

    def visible(items)
      items.reject { |item| item["removed"] }
    end

    def validate_snapshot!(added, existing:)
      raise ArgumentError, "Expected a complete meal preview" unless added.is_a?(Array) && added.size <= 3

      keys = added.map.with_index do |raw, index|
        suggestion = raw.deep_stringify_keys
        raise ArgumentError, "Expected a meal series" unless suggestion["kind"] == SLOT_RUN_KIND
        fields = suggestion.fetch("fields")
        raise ArgumentError, "Meal label is required" unless fields["label"].is_a?(String) && fields["label"].strip.present?
        capacity = fields.fetch("capacity", 1)
        raise ArgumentError, "Meal capacity must be positive" unless capacity.is_a?(Integer) && capacity.positive?
        time = fields["time"]
        raise ArgumentError, "Invalid meal time" unless time.nil? || time == "" || (time.is_a?(String) && time.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/))
        if fields["start_date"].present?
          start_date = Date.iso8601(fields.fetch("start_date"))
          end_date = Date.iso8601(fields.fetch("end_date"))
          raise ArgumentError, "Meal dates must span at most 60 days" unless (end_date - start_date).to_i.between?(0, 59)
        else
          start_offset = fields.fetch("start_day_offset", 0)
          end_offset = fields.fetch("end_day_offset", start_offset)
          unless start_offset.is_a?(Integer) && end_offset.is_a?(Integer) && start_offset.between?(0, 59) && end_offset.between?(start_offset, 59)
            raise ArgumentError, "Meal offsets must be within 60 days"
          end
        end
        key = suggestion["source_key"]
        raise ArgumentError, "Invalid meal series identity" unless key.is_a?(String) && key.match?(/\A[a-zA-Z0-9_-]{1,80}\z/)
        key
      end
      raise ArgumentError, "Duplicate meal series" unless keys.uniq.size == keys.size

      previous_keys = existing.map { |item| item.fetch("source_key").sub(/:\d+\z/, "") }.uniq
      if (keys - previous_keys).any? && (previous_keys - keys).any?
        raise ArgumentError, "Meal series identity changed; the existing preview was preserved"
      end
    end

    def sanitize_slot_fields(fields)
      fields = fields.to_h.deep_stringify_keys.slice(*EDITABLE_SLOT_FIELDS)
      fields["date"] = Date.iso8601(fields.fetch("date")).iso8601 if fields["date"].present?
      fields["capacity"] = fields["capacity"].to_i if fields.key?("capacity")
      fields
    rescue Date::Error
      fields
    end

    def valid_slot(item, project:)
      fields = item.fetch("fields")
      Slot.new(
        project:,
        label: fields["label"],
        date: fields["date"],
        starts_at_time: fields["time"].presence,
        capacity: fields["capacity"]
      )
    end

    def source_key(suggestion, source_index, occurrence_index)
      base = suggestion["source_key"].presence || "meal-slots-#{source_index}"
      "#{base}:#{occurrence_index}"
    end

    def stable_id(source_key)
      Digest::SHA256.hexdigest(source_key).then do |hex|
        "#{hex[0, 8]}-#{hex[8, 4]}-4#{hex[13, 3]}-8#{hex[17, 3]}-#{hex[20, 12]}"
      end
    end

    def candidate(fields:, source_key:, metadata: {})
      Data.define(:source_key, :fields, :metadata) do
        def to_h
          {
            "id" => Planner::PendingItems.stable_id(source_key),
            "source_key" => source_key,
            "kind" => Planner::PendingItems::SLOT_KIND,
            "fields" => fields,
            "suggested_fields" => fields,
            "removed" => false,
            "user_edits" => {},
            "conflict" => nil
          }.merge(metadata)
        end
      end.new(source_key, fields, metadata)
    end

    def expand_slot_run(suggestion, project:, source_index:)
      fields = suggestion.fetch("fields")
      start_date = if fields["start_date"].present?
        Date.iso8601(fields.fetch("start_date"))
      elsif project.starts_on
        project.starts_on + fields.fetch("start_day_offset", 0).to_i
      end
      length = if fields["end_date"].present?
        return [] unless start_date
        (Date.iso8601(fields.fetch("end_date")) - start_date).to_i + 1
      else
        fields.fetch("end_day_offset", fields.fetch("start_day_offset", 0)).to_i -
          fields.fetch("start_day_offset", 0).to_i + 1
      end
      return [] unless length.between?(1, 60)

      length.times.map do |occurrence_index|
        key = source_key(suggestion, source_index, occurrence_index)
        candidate(
          source_key: key,
          fields: sanitize_slot_fields(
            "label" => fields["label"],
            "date" => start_date && (start_date + occurrence_index).iso8601,
            "time" => fields["time"],
            "capacity" => fields.fetch("capacity", 1)
          ),
          metadata: { "day_offset" => fields.fetch("start_day_offset", 0).to_i + occurrence_index }
        )
      end
    rescue Date::Error
      []
    end

    def merge(previous, candidate)
      suggested_fields = candidate.fields
      user_edits = previous.fetch("user_edits", {})
      conflicts = user_edits.each_with_object({}) do |(field, edited_value), result|
        previous_suggested = previous.fetch("suggested_fields", previous.fetch("fields"))[field]
        unresolved = previous.dig("conflict", "fields", field).present?
        next if suggested_fields[field] == edited_value
        next if suggested_fields[field] == previous_suggested && !unresolved

        result[field] = {
          "edited" => edited_value,
          "suggested" => suggested_fields[field]
        }
      end

      candidate.to_h.merge(
        "id" => previous.fetch("id"),
        "fields" => suggested_fields.merge(user_edits),
        "suggested_fields" => suggested_fields,
        "removed" => previous.fetch("removed", false),
        "user_edits" => user_edits,
        "conflict" => conflicts.presence && { "type" => "field_changes", "fields" => conflicts },
        "day_offset" => candidate.to_h["day_offset"],
        "removed_revision" => previous["removed_revision"]
      )
    end

    def preserved_by_leader?(item)
      item.fetch("removed", false) || item.fetch("user_edits", {}).present?
    end
  end
end
