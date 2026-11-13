module PublicSlotsHelper
  def slot_summary(slot)
    "#{slot.date.strftime("%A, %B %-d")} · #{slot.label}"
  end

  # One phrase for a held spot, on its row and in the toast that confirms it.
  def claimed_slot_phrase(slot)
    slot.label.downcase == "dinner" ? "You’re bringing dinner" : "You’re signed up"
  end

  def claimed_slot_notice(slot)
    day = slot.date.strftime("%A, %B %-d")
    slot.label.downcase == "dinner" ? "#{claimed_slot_phrase(slot)} #{day}." : "#{claimed_slot_phrase(slot)} for #{slot.label} on #{day}."
  end
end
