module PlannerSessionsHelper
  PLANNER_TOOL_ICONS = {
    "planner" => :projects,
    "people" => :people,
    "oversight" => :oversight,
    "tasks" => :tasks,
    "schedule" => :schedule,
    "signup_sheet" => :schedule,
    "budget" => :budget,
    "list" => :list,
    "messages" => :messages,
    "docs" => :docs
  }.freeze

  PLANNER_TOOL_COLORS = {
    "planner" => "text-tool-docs",
    "people" => "text-tool-list",
    "oversight" => "text-tool-messages",
    "tasks" => "text-tool-tasks",
    "schedule" => "text-tool-schedule",
    "signup_sheet" => "text-tool-signup",
    "budget" => "text-tool-budget",
    "list" => "text-tool-list",
    "messages" => "text-tool-messages",
    "docs" => "text-tool-docs"
  }.freeze

  # A nil tool is the Skills needed group, the one Planner kind that belongs to no Tool.
  def planner_tool_label(tool)
    return "Skills needed" if tool.nil?

    Project::TOOL_LABELS.fetch(tool, tool.to_s.humanize)
  end

  def planner_tool_icon(tool, size: 16)
    icon(PLANNER_TOOL_ICONS.fetch(tool, tool.nil? ? :people : :projects), size:, class: PLANNER_TOOL_COLORS.fetch(tool, "text-ink-2"))
  end

  def planner_pending_summary(item)
    Planner::PendingItems.summary(item)
  rescue KeyError, ArgumentError
    item.dig("fields", "title").presence || item.dig("fields", "name").presence || item.dig("fields", "description").presence || "Untitled item"
  end

  def planner_pending_field_errors(item, errors)
    Array(errors).group_by { |error| planner_pending_error_field(item, error) }
  end

  def planner_pending_tool(item)
    return "project_dates" if item["kind"] == "shift_project_dates"

    Planner::PendingItems.tool(item)
  rescue KeyError, ArgumentError
    "tasks"
  end

  def planner_schedule_item_options(planner_session, selected_reference = nil)
    options = planner_session.visible_pending_items.filter_map do |item|
      next unless item["kind"] == "schedule_item"

      [ item.dig("fields", "title"), item.fetch("source_key") ]
    end
    options.concat(planner_session.project.schedule_items.chronological.map do |schedule_item|
      [ schedule_item.title, Planner::PendingItems.existing_schedule_item_source_key(schedule_item) ]
    end)
    if selected_reference.present? && options.none? { |_, reference| reference == selected_reference }
      options << [ "Unknown session", selected_reference ]
    end
    options
  end

  def planner_schedule_item_label(planner_session, reference)
    planner_schedule_item_options(planner_session, reference).find { |_, value| value == reference }&.first
  end

  def planner_date(value)
    Date.iso8601(value.to_s).strftime("%B %-d, %Y")
  rescue Date::Error
    value
  end

  def planner_time(value)
    Time.strptime(value.to_s, "%H:%M").strftime("%-I:%M %p")
  rescue ArgumentError
    value
  end

  def planner_conflict_value(value)
    return "Not set" if value.blank?
    if value.is_a?(Array)
      return value.map { |entry| entry.is_a?(Hash) ? "#{entry['name']} (#{entry['type'].to_s.humanize})" : entry.to_s }.to_sentence
    end

    value.to_s
  end

  private
    def planner_pending_error_field(item, error)
      message = error.to_s
      special_fields = {
        "Choose a Project start date or a due date" => "due_on",
        "At least one valid column" => "columns",
        "Session does not match" => "schedule_item_source_key"
      }
      special_fields.each { |prefix, field| return field if message.start_with?(prefix) }

      Planner::PendingItems.fields_for(item.fetch("kind")).each do |field, definition|
        labels = [ definition.fetch(:label), field.humanize ]
        return field if labels.any? { |label| message.start_with?(label) }
      end
      nil
    rescue KeyError
      nil
    end
end
