module PublicSlotsHelper
  def slot_summary(slot)
    "#{slot.date.strftime("%A, %B %-d")} · #{slot.label}"
  end

  # One phrase for a held spot, on the row that confirms it.
  def claimed_slot_phrase(slot)
    slot.label.downcase == "dinner" ? "You’re bringing dinner" : "You’re signed up"
  end
end
