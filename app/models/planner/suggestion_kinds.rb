module Planner
  module SuggestionKinds
    TIME_PATTERN = "^#{FieldValidation::TIME_PATTERN}$"

    KINDS = {
      "shift_project_dates" => {
        label: "Project dates",
        tool: nil,
        summary: ->(fields) { "Move all saved Project, Task, Schedule, Slot and List dates #{fields.fetch('days')} days. Keep existing claims and assignments." },
        fields: {
          "days" => { label: "Days to move (negative moves earlier)", input: :number, min: -365, max: 365,
            schema: { type: "integer", minimum: -365, maximum: 365 } }
        },
        create: ->(project, fields) { ProjectDateShift.new(project, days: fields.fetch("days")).call }
      },
      # A skill the Team needs, written to Project#skills_needed; no Tool. Never a person (ADR 0002).
      "skill" => {
        label: "Skills needed",
        tool: nil,
        summary: ->(fields) { Skills.label(fields.fetch("name")) },
        fields: {
          "name" => { label: "Skill", input: :text, schema: { type: "string" } }
        },
        create: ->(project, fields) { project.update!(skills_needed: project.skills_needed + [ fields.fetch("name") ]) }
      },
      "enable_tool" => {
        label: "Tools",
        tool: ->(fields) { fields.fetch("tool") },
        summary: ->(fields) { Project::TOOL_LABELS.fetch(fields.fetch("tool")) },
        fields: {
          "tool" => {
            label: "Tool",
            input: :select,
            options: Project::TOOLS.index_with { |tool| Project::TOOL_LABELS.fetch(tool) },
            schema: { type: "string", enum: Project::TOOLS }
          }
        },
        create: ->(_project, _fields) { }
      },
      "task" => {
        label: "Tasks",
        tool: "tasks",
        summary: ->(fields) { fields.fetch("title") },
        fields: {
          "title" => { label: "Title", input: :text, schema: { type: "string" } },
          "details" => { label: "Details", input: :textarea, schema: { type: "string" } },
          "due_in_days" => {
            label: "Due in days",
            input: :number,
            schema: { type: [ "integer", "null" ] }
          },
          "role" => { label: "Open role", input: :text, schema: { type: [ "string", "null" ] } }
        },
        create: lambda do |project, fields|
          due_in_days = fields["due_in_days"]
          project.tasks.create!(
            title: fields.fetch("title"),
            details: fields.fetch("details"),
            due_on: due_in_days.present? ? base_date(project) + due_in_days.to_i : nil
          )
        end
      },
      "schedule_item" => {
        label: "Schedule items",
        tool: "schedule",
        summary: ->(fields) { fields.fetch("title") },
        fields: {
          "title" => { label: "Title", input: :text, schema: { type: "string" } },
          "day_offset" => { label: "Day", input: :number, schema: { type: "integer" } },
          "starts_at" => {
            label: "Starts at",
            input: :time,
            schema: { type: [ "string", "null" ], pattern: TIME_PATTERN }
          },
          "ends_at" => {
            label: "Ends at",
            input: :time,
            schema: { type: [ "string", "null" ], pattern: TIME_PATTERN }
          },
          "location" => { label: "Location", input: :text, schema: { type: [ "string", "null" ] } }
        },
        create: lambda do |project, fields|
          project.schedule_items.create!(
            title: fields.fetch("title"),
            date: base_date(project) + fields.fetch("day_offset").to_i,
            starts_at_time: fields["starts_at"].presence,
            ends_at_time: fields["ends_at"].presence,
            location: fields["location"].presence
          )
        end
      },
      "slot_run" => {
        label: "Slot runs",
        tool: "signup_sheet",
        summary: ->(fields) { fields.fetch("label") },
        fields: {
          "label" => { label: "Label", input: :text, schema: { type: "string" } },
          "start_day_offset" => {
            label: "Start day",
            input: :number,
            schema: { type: "integer" }
          },
          "end_day_offset" => {
            label: "End day",
            input: :number,
            schema: { type: "integer" }
          },
          "time" => {
            label: "Time",
            input: :time,
            schema: { type: [ "string", "null" ], pattern: TIME_PATTERN }
          },
          "capacity" => {
            label: "Capacity",
            input: :number,
            min: 1,
            schema: { type: "integer", minimum: 1 }
          },
          "schedule_item_source_key" => {
            label: "Schedule item",
            input: :text,
            schema: { type: [ "string", "null" ] }
          }
        },
        create: lambda do |project, fields|
          run = SlotRun.new(
            project:,
            label: fields.fetch("label"),
            start_date: base_date(project) + fields.fetch("start_day_offset").to_i,
            end_date: base_date(project) + fields.fetch("end_day_offset").to_i,
            starts_at_time: fields["time"].presence,
            capacity: fields.fetch("capacity").to_i
          )
          raise ActiveRecord::RecordInvalid, run unless run.save
        end
      },
      "booking" => {
        label: "Bookings",
        tool: "budget",
        summary: ->(fields) { fields.fetch("description") },
        fields: {
          "description" => { label: "Description", input: :text, schema: { type: "string" } },
          "estimated_dollars" => {
            label: "Estimated dollars",
            input: :number,
            min: 0,
            step: "0.01",
            schema: { type: "number", minimum: 0 }
          },
          "role" => { label: "Open role", input: :text, schema: { type: [ "string", "null" ] } }
        },
        create: lambda do |project, fields|
          project.budget_lines.create!(
            kind: :booking,
            description: fields.fetch("description"),
            estimated: fields.fetch("estimated_dollars")
          )
        end
      },
      "purchase" => {
        label: "Purchases",
        tool: "budget",
        summary: ->(fields) { fields.fetch("description") },
        fields: {
          "description" => { label: "Description", input: :text, schema: { type: "string" } },
          "estimated_dollars" => {
            label: "Estimated dollars",
            input: :number,
            min: 0,
            step: "0.01",
            schema: { type: "number", minimum: 0 }
          },
          "role" => { label: "Open role", input: :text, schema: { type: [ "string", "null" ] } }
        },
        create: lambda do |project, fields|
          project.budget_lines.create!(
            kind: :purchase,
            description: fields.fetch("description"),
            estimated: fields.fetch("estimated_dollars")
          )
        end
      },
      "list" => {
        label: "Lists",
        tool: "list",
        summary: ->(fields) { fields.fetch("name") },
        fields: {
          "name" => { label: "Name", input: :text, schema: { type: "string" } },
          "columns" => {
            label: "Columns",
            input: :columns,
            schema: {
              type: "array",
              minItems: 1,
              items: {
                type: "object",
                additionalProperties: false,
                properties: {
                  name: { type: "string" },
                  type: { type: "string", enum: ListColumn.column_types.keys }
                },
                required: %w[name type]
              }
            }
          }
        },
        create: lambda do |project, fields|
          list = project.lists.create!(name: fields.fetch("name"))
          fields.fetch("columns").each do |column|
            column = column.stringify_keys
            list.columns.create!(name: column.fetch("name"), column_type: column.fetch("type"))
          end
        end
      }
    }.freeze

    module_function

    def provider_schema
      # One flat suggestion object keeps the structured-output grammar small enough for OpenRouter.
      {
        type: "object",
        additionalProperties: false,
        properties: {
          kind: { type: "string", enum: KINDS.keys },
          fields: {
            type: "object",
            additionalProperties: false,
            properties: merged_field_properties,
            required: []
          }
        },
        required: %w[kind fields]
      }
    end

    def permitted_fields
      simple_fields = KINDS.values.flat_map { |definition| definition.fetch(:fields).keys }.uniq - [ "columns" ]
      simple_fields.map(&:to_sym) + [ { columns: [ %i[name type] ] } ]
    end

    def sanitize_fields(kind, fields)
      definition = KINDS.fetch(kind)
      sanitized = fields.to_h.deep_stringify_keys.slice(*definition.fetch(:fields).keys)
      if sanitized["columns"]
        sanitized["columns"] = sanitized.fetch("columns").map do |column|
          column.to_h.stringify_keys.slice("name", "type")
        end
      end
      sanitized.reject { |_, value| value.nil? }
    end

    def create!(project, suggestion)
      suggestion = suggestion.stringify_keys
      kind = suggestion.fetch("kind")
      definition = KINDS.fetch(kind)
      fields = sanitize_fields(kind, suggestion.fetch("fields"))
      validate_fields!(kind, fields)
      tool = definition.fetch(:tool)
      tool = tool.call(fields) if tool.respond_to?(:call)
      project.update!(enabled_tools: (project.enabled_tools + [ tool ]).uniq) if tool
      definition.fetch(:create).call(project, fields)
    end

    def label(kind)
      KINDS.fetch(kind).fetch(:label)
    end

    def summary(suggestion)
      suggestion = suggestion.stringify_keys
      definition = KINDS.fetch(suggestion.fetch("kind"))
      definition.fetch(:summary).call(suggestion.fetch("fields"))
    end

    def fields_for(kind)
      KINDS.fetch(kind).fetch(:fields)
    end

    def base_date(project)
      project.starts_on || Date.current
    end

    def validate_fields!(kind, fields)
      missing = required_field_names(kind).reject { |name| field_present?(fields[name]) }
      unless missing.empty?
        kind_label = KINDS.fetch(kind).fetch(:label)
        raise ArgumentError, "#{kind_label} suggestion is missing #{missing.to_sentence}"
      end

      invalid = invalid_field_messages(kind, fields)
      raise ArgumentError, invalid.to_sentence if invalid.any?
    end

    def invalid_field_messages(kind, fields)
      messages = FieldValidation.errors(kind, fields)
      messages << "Skill must be one skill name" if kind == "skill" && !Skills.normalize(fields["name"]).one?
      messages << "Columns must each have a name and a type" if kind == "list" && !FieldValidation.valid_columns?(fields["columns"])
      messages
    end

    def required_field_names(kind)
      KINDS.fetch(kind).fetch(:fields).filter_map do |name, field|
        name unless nullable_field_schema?(field.fetch(:schema))
      end
    end

    def nullable_field_schema?(schema)
      type = schema[:type]
      type.is_a?(Array) && type.include?("null")
    end

    def field_present?(value)
      return false if value.nil?
      return value.any? if value.is_a?(Array)

      true
    end

    def merged_field_properties
      @merged_field_properties ||= begin
        merged = {}
        KINDS.each_value do |definition|
          definition.fetch(:fields).each do |name, field|
            slim = slim_provider_schema(field.fetch(:schema))
            if merged.key?(name)
              raise ArgumentError, "Planner field #{name} has conflicting provider schemas" unless merged[name] == slim
            else
              merged[name] = slim
            end
          end
        end
        merged.freeze
      end
    end

    GRAMMAR_BLOAT_KEYS = %i[pattern minimum minItems required].freeze

    def slim_provider_schema(schema)
      schema = schema.deep_dup
      scrub_grammar_bloat!(schema)
      make_scalars_non_null!(schema)
      schema
    end

    def scrub_grammar_bloat!(schema)
      return unless schema.is_a?(Hash)

      GRAMMAR_BLOAT_KEYS.each { |key| schema.delete(key) }
      schema.fetch(:properties, {}).each_value { |property| scrub_grammar_bloat!(property) }
      scrub_grammar_bloat!(schema[:items]) if schema[:items].is_a?(Hash)
    end

    def make_scalars_non_null!(schema)
      return unless schema.is_a?(Hash)

      schema.fetch(:properties, {}).each_value { |property| make_scalars_non_null!(property) }
      make_scalars_non_null!(schema[:items]) if schema[:items].is_a?(Hash)

      # Merged fields are optional, so omission already means "none"; Anthropic caps union-typed params at 16.
      schema[:type] = (schema[:type] - [ "null" ]).sole if schema[:type].is_a?(Array)
    end

    private_class_method :validate_fields!, :required_field_names, :invalid_field_messages, :nullable_field_schema?, :field_present?,
      :merged_field_properties, :slim_provider_schema, :scrub_grammar_bloat!, :make_scalars_non_null!
  end
end
