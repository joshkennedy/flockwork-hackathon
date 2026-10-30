module Planner
  module SuggestionKinds
    TIME_PATTERN = "^([01]\\d|2[0-3]):[0-5]\\d$"

    KINDS = {
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
          "day_offset" => { label: "Day offset", input: :number, schema: { type: "integer" } },
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
            label: "Start day offset",
            input: :number,
            schema: { type: "integer" }
          },
          "end_day_offset" => {
            label: "End day offset",
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
      {
        anyOf: KINDS.map do |kind, definition|
          {
            type: "object",
            additionalProperties: false,
            properties: {
              id: { type: "string", format: "uuid" },
              kind: { type: "string", enum: [ kind ] },
              fields: fields_schema(definition),
              status: { type: "string", enum: %w[proposed kept edited dropped] }
            },
            required: %w[id kind fields status]
          }
        end
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
      sanitized
    end

    def create!(project, suggestion)
      suggestion = suggestion.stringify_keys
      definition = KINDS.fetch(suggestion.fetch("kind"))
      fields = sanitize_fields(suggestion.fetch("kind"), suggestion.fetch("fields"))
      tool = definition.fetch(:tool)
      tool = tool.call(fields) if tool.respond_to?(:call)
      project.update!(enabled_tools: (project.enabled_tools + [ tool ]).uniq)
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

    def fields_schema(definition)
      fields = definition.fetch(:fields)
      {
        type: "object",
        additionalProperties: false,
        properties: fields.transform_values { |field| field.fetch(:schema) },
        required: fields.keys
      }
    end
    private_class_method :fields_schema
  end
end
