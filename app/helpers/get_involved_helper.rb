module GetInvolvedHelper
  WINDOWS = [ "This week", "Next week", "Later" ].freeze

  # Same windows the sign-up sheet uses, so the two pages read the same.
  def slots_by_window(slots)
    grouped = slots.group_by { |slot| slot_window(slot.date) }
    WINDOWS.filter_map { |window| [ window, grouped[window] ] if grouped[window] }
  end

  def slot_window(date)
    if date <= Date.current.end_of_week then "This week"
    elsif date <= Date.current.next_week.end_of_week then "Next week"
    else "Later"
    end
  end

  # The names inside the claimers' pill; "signed up" sits beside it so the pill never truncates the verb.
  def who_is_going(slot)
    names = slot.slot_claims.map { |claim| claim.person.name }
    case names.size
    when 0 then nil
    when 1, 2 then names.to_sentence
    else "#{names.first} and #{names.size - 1} others"
    end
  end

  def claim_label(slot)
    slot.label.downcase == "dinner" ? "I Can Bring Dinner" : "I Can Help"
  end

  def unassigned_task_label(project)
    count = project.tasks.open.where(assignee_id: nil).count
    count == 1 ? "1 unassigned Task" : "#{count} unassigned Tasks"
  end

  # Plain counts only (DESIGN.md): "3 of 8 spots filled · next open Sat, Nov 8".
  def momentum_line(slots)
    return if slots.empty?

    total = pluralize(slots.sum(&:capacity), SlotsHelper.count_noun(slots))
    filled = "#{slots.sum(&:claims_count)} of #{total} filled"
    next_open = slots.reject(&:full?).first
    next_open ? "#{filled} · next open #{next_open.date.strftime("%a, %b %-d")}" : "#{filled} · all covered"
  end
end
