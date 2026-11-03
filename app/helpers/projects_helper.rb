module ProjectsHelper
  TAB_ORDER = %w[signup_sheet tasks schedule list budget docs messages].freeze
  TOOL_RECORDS = { "signup_sheet" => :slots, "tasks" => :tasks, "schedule" => :schedule_items, "list" => :lists,
                   "budget" => :budget_lines, "docs" => :doc_items, "messages" => :messages }.freeze

  # Recipients live in the side column, so every other enabled Tool becomes a tab:
  # Tools with something in them first, then by how much work each usually carries.
  def project_tabs(project)
    (project.enabled_tools - [ "recipients" ]).sort_by do |tool|
      records = TOOL_RECORDS[tool]
      [ records && project.public_send(records).exists? ? 0 : 1, TAB_ORDER.index(tool) || TAB_ORDER.size ]
    end
  end

  def project_planned?(project)
    TOOL_RECORDS.values.any? { |records| project.public_send(records).exists? }
  end

  def project_date_range(starts_on, ends_on)
    format = ->(date) { date.strftime(date.year == Date.current.year ? "%b %-d" : "%b %-d, %Y") }
    return format.(starts_on) if ends_on.nil? || starts_on == ends_on
    return "Until #{format.(ends_on)}" if starts_on.nil?

    "#{format.(starts_on)} – #{format.(ends_on)}"
  end

  # Label/value pairs for the status strip, in plain counts (DESIGN.md: never bars or percentages).
  def project_status_items(project)
    items = []
    items << [ "When", project_date_range(project.starts_on, project.ends_on) ] if project.starts_on || project.ends_on

    if project.enabled_tools.include?("signup_sheet") && (slots = project.slots.to_a).any?
      items << [ "Covered", "#{slots.sum(&:claims_count)} of #{pluralize(slots.sum(&:capacity), slot_noun(slots))}" ]
      next_open = upcoming_open_slots(slots).first
      items << [ "Next open", next_open ? next_open.date.strftime("%a, %b %-d") : "All covered" ]
    elsif project.enabled_tools.include?("tasks") && (open_tasks = project.tasks.open.to_a).any?
      items << [ "Assigned", "#{open_tasks.count(&:assignee_id)} of #{pluralize(open_tasks.size, "open task")}" ]
      next_due = open_tasks.select(&:due_on).min_by(&:due_on)
      items << [ "Next due", next_due ? next_due.due_on.strftime("%a, %b %-d") : "No due dates" ]
    end

    items
  end

  # Relative labels read faster than calendar dates; the exact day stays in the <time> title.
  def task_due_label(date, today: Date.current)
    days = (date - today).to_i
    case days
    when ...0 then "Overdue by #{pluralize(-days, "day")}"
    when 0 then "Due today"
    when 1 then "Due tomorrow"
    when 2..13 then "Due in #{days} days"
    when 14..55 then "Due in #{pluralize((days / 7.0).round, "week")}"
    else "Due #{date.strftime(date.year == today.year ? "%b %-d" : "%b %-d, %Y")}"
    end
  end

  # The one open need worth saying out loud, or nil. :slot is the next open Slot
  # this person hasn't claimed, for a Volunteer's one-tap claim.
  def project_guidance(project, person)
    return if project.done_at.present?

    if project.enabled_tools.include?("signup_sheet")
      open_slots = upcoming_open_slots(project.slots.includes(:slot_claims).to_a)
      spots = open_slots.sum { |slot| slot.capacity - slot.claims_count }
      if spots.positive?
        next_slot = open_slots.find { |slot| slot.slot_claims.none? { |claim| claim.person_id == person.id } }
        noun = slot_noun(open_slots)
        return {
          kind: :spots,
          title: noun == "spot" ? "#{pluralize(spots, "spot")} still open" : "#{pluralize(spots, noun)} still #{spots == 1 ? "needs" : "need"} someone",
          detail: next_slot && "#{next_slot.date.strftime("%A, %B %-d")} is the next open spot.",
          slot: next_slot
        }
      end
    end

    if project.enabled_tools.include?("tasks")
      unassigned = project.tasks.open.where(assignee_id: nil).count
      if unassigned.positive?
        return { kind: :tasks, title: unassigned == 1 ? "1 task has no one on it" : "#{unassigned} tasks have no one on them" }
      end
    end

    nil
  end

  private
    def upcoming_open_slots(slots)
      slots.reject(&:full?).select { |slot| slot.date >= Date.current }.sort_by { |slot| [ slot.date, slot.starts_at_time.to_s ] }
    end

    # Counts are in spots: "dinner" when every Slot is one person with a shared label, else "spot".
    def slot_noun(slots)
      labels = slots.map { |slot| slot.label.downcase }.uniq
      labels.one? && slots.all? { |slot| slot.capacity == 1 } ? labels.first : "spot"
    end
end
