class SlotReminderJob < ApplicationJob
  def perform
    Slot.where(date: Date.tomorrow).includes(slot_claims: :person).find_each do |slot|
      slot.with_lock do
        next unless slot.date == Date.tomorrow

        slot.slot_claims.each do |claim|
          next if claim.person.notifications.where(created_at: Date.current.all_day).exists?(kind: "slot_reminder", notifiable: slot)

          Notifier.notify(recipient: claim.person, kind: "slot_reminder", notifiable: slot)
        end
      end
    end
  end
end
