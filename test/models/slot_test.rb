require "test_helper"

class SlotTest < ActiveSupport::TestCase
  test "random claim attempts never exceed Slot capacity" do
    project = projects(:community_meal)
    members = 10.times.map do |index|
      person = project.organization.people.create!(name: "Property Member #{index + 1}")
      project.memberships.create!(person:, role: :volunteer)
      person
    end
    random = Random.new(20_261_031)

    30.times do |index|
      capacity = random.rand(1..5)
      attempts = random.rand(0..10)
      slot = project.slots.create!(date: Date.new(2027, 3, 1) + index, label: "Property Slot #{index + 1}", capacity:)

      members.first(attempts).each { |member| slot.claim(member) }

      assert_operator slot.slot_claims.count, :<=, capacity,
        "capacity #{capacity} with #{attempts} claim attempts"
    end
  end
end
