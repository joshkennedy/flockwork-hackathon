# Counts and dates only, shared by the Project read and scheduled summaries.
class ProjectRisk
  WINDOW_DAYS = 7

  attr_reader :open_spots, :overdue_tasks, :pending_invitations, :days_until_start

  def initialize(project, today: Date.current)
    @open_spots = 0
    @overdue_tasks = 0
    @pending_invitations = 0
    return unless project.active?

    if project.enabled_tools.include?("signup_sheet")
      @open_spots = project.slots.with_open_spots.where(date: today...(today + WINDOW_DAYS))
        .sum("capacity - claims_count")
    end
    @overdue_tasks = project.tasks.open.where("due_on < ?", today).count if project.enabled_tools.include?("tasks")
    @pending_invitations = project.invitations.pending.count
    @days_until_start = (project.starts_on - today).to_i if project.starts_on && project.starts_on >= today
  end

  def attention_needed?
    open_spots.positive? || overdue_tasks.positive?
  end

  def action_tool
    return "signup_sheet" if open_spots.positive?
    "tasks" if overdue_tasks.positive?
  end
end
