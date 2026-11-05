require "test_helper"
require_relative "../support/method_stubs"

class ShiftedSlotReminderTest < ActiveSupport::TestCase
  include MethodStubs
  test "shifted claimed Slots receive one reminder on their new day before" do
    travel_to Time.zone.local(2027, 2, 10, 12)
    project = projects(:community_meal)
    slot = project.slots.create!(label: "Serve", date: Date.tomorrow, capacity: 1)
    person = people(:volunteer)
    slot.slot_claims.create!(person:)
    2.times { SlotReminderJob.perform_now }
    assert_equal 1, person.notifications.where(kind: :slot_reminder, notifiable: slot).count
    ProjectDateShift.new(project, days: 7).call
    travel 7.days
    2.times { SlotReminderJob.perform_now }
    assert_equal 2, person.notifications.where(kind: :slot_reminder, notifiable: slot).count
  ensure
    travel_back
  end

  test "a Slot moved after selection is not reminded for its old date" do
    project = projects(:community_meal)
    slot = project.slots.create!(label: "Serve", date: Date.tomorrow, capacity: 1)
    person = people(:volunteer)
    slot.slot_claims.create!(person:)
    selected = Slot.where(date: Date.tomorrow).includes(slot_claims: :person).to_a
    relation = Slot.where(id: selected.map(&:id))
    stub_method(relation, :merge, ->(*) { relation }) do
      stub_method(relation, :where, ->(*) { relation }) do
        stub_method(relation, :includes, ->(*) { relation }) do
          stub_method(relation, :find_each, ->(&block) {
            selected.each do |candidate|
              Slot.find(candidate.id).update!(date: Date.tomorrow + 7)
              block.call(candidate)
            end
          }) do
            stub_method(Slot, :joins, ->(*) { relation }) do
              assert_no_difference -> { person.notifications.where(kind: :slot_reminder, notifiable: slot).count } do
                SlotReminderJob.perform_now
              end
            end
          end
        end
      end
    end
    assert_equal Date.tomorrow + 7, slot.reload.date
  end
end
