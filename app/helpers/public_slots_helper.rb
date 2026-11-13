module PublicSlotsHelper
  def claimed_slot_notice(slot)
    day = slot.date.strftime("%A, %B %-d")
    slot.label.downcase == "dinner" ? "You’re bringing dinner #{day}." : "You’re signed up for #{slot.label} on #{day}."
  end
end
