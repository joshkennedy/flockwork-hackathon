module PlannerSessionsHelper
  PLANNER_TOOL_ICONS = {
    "tasks" => :tasks,
    "schedule" => :schedule,
    "signup_sheet" => :schedule,
    "budget" => :budget,
    "list" => :list,
    "messages" => :messages,
    "docs" => :docs
  }.freeze

  PLANNER_TOOL_COLORS = {
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

  def planner_tool_icon(tool)
    icon(PLANNER_TOOL_ICONS.fetch(tool, tool.nil? ? :people : :projects), class: PLANNER_TOOL_COLORS.fetch(tool, "text-ink-2"))
  end

  def planner_pending_summary(item)
    Planner::PendingItems.summary(item)
  rescue KeyError, ArgumentError
    item.dig("fields", "title").presence || item.dig("fields", "name").presence || item.dig("fields", "description").presence || "Untitled item"
  end

  def planner_pending_tool(item)
    Planner::PendingItems.tool(item)
  rescue KeyError, ArgumentError
    "tasks"
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
end
