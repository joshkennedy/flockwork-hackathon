require "test_helper"

class SlotReminderDeletedProjectTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  test "a soft-deleted Project sends no Slot reminder" do
    travel_to Time.zone.local(2027, 2, 10, 12) do
      project = projects(:community_meal)
      slot = project.slots.create!(label: "Serve", date: Date.tomorrow, capacity: 1)
      person = people(:volunteer)
      slot.slot_claims.create!(person: person)
      project.update!(deleted_at: Time.current)

      assert_emails 0 do
        perform_enqueued_jobs do
          SlotReminderJob.perform_now
        end
      end
      assert_equal 0, person.notifications.where(kind: :slot_reminder, notifiable: slot).count
    end
  end
end
