module SlotsHelper
  def self.count_noun(slots)
    labels = slots.map { |slot| slot.label.downcase }.uniq
    labels.one? && slots.all? { |slot| slot.capacity == 1 } ? labels.first : "spot"
  end

  # The Sign-up sheet's reading order, by calendar week from today: Past, This week, Next week, then Later.
  def slot_weeks(slots)
    past, upcoming = slots.partition { |slot| slot.date < Date.current }
    this_week, upcoming = upcoming.partition { |slot| slot.date <= Date.current.end_of_week }
    next_week, later = upcoming.partition { |slot| slot.date <= Date.current.next_week.end_of_week }
    { past:, this_week:, next_week:, later: }
  end

  def later_slots_meta(slots)
    "#{pluralize(slots.size, "Slot")}, #{pluralize(slots.sum { |slot| [ slot.capacity - slot.claims_count, 0 ].max }, "spot")} left"
  end
end
