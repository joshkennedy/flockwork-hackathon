require "test_helper"

class SlotTest < ActiveSupport::TestCase
  test "claim stores a note when the Slot asks a question" do
    slot = projects(:community_meal).slots.create!(
      date: Date.tomorrow,
      label: "Main dishes",
      capacity: 8,
      claim_prompt: "What are you bringing?"
    )

    claim = slot.claim(people(:volunteer), note: "Baked ziti")

    assert_predicate claim, :persisted?
    assert_equal "Baked ziti", claim.note
  end

  test "a prompted Slot requires a short claim note" do
    slot = projects(:community_meal).slots.create!(
      date: Date.tomorrow,
      label: "Desserts",
      capacity: 8,
      claim_prompt: "What are you bringing?"
    )

    missing = slot.claim(people(:volunteer))
    too_long = slot.claim(people(:other_volunteer), note: "x" * 81)

    assert_not_predicate missing, :persisted?
    assert_equal [ "can't be blank" ], missing.errors[:note]
    assert_not_predicate too_long, :persisted?
    assert_equal [ "is too long (maximum is 80 characters)" ], too_long.errors[:note]
  end

  test "linked Schedule item must belong to the same Project" do
    project = projects(:community_meal)
    other_item = projects(:building_cleanup).schedule_items.create!(title: "Session 3", date: "2027-04-18")
    slot = project.slots.build(label: "Teacher", date: "2027-04-18", schedule_item: other_item)

    assert_not slot.valid?
    assert_equal [ "must belong to the same Project" ], slot.errors[:schedule_item]
  end

  test "linked Slot date follows its Schedule item when either record changes" do
    project = projects(:community_meal)
    session = project.schedule_items.create!(title: "Session 3", date: "2027-04-18")
    slot = project.slots.create!(label: "Teacher", date: "2027-01-01", schedule_item: session)
    claim = slot.slot_claims.create!(person: people(:volunteer))

    assert_equal session.date, slot.date

    session.update!(date: "2027-04-25")

    assert_equal Date.new(2027, 4, 25), slot.reload.date
    assert_equal claim, slot.slot_claims.sole
  end

  test "deleting a Schedule item keeps its linked Slots and Claims" do
    project = projects(:community_meal)
    session = project.schedule_items.create!(title: "Session 3", date: "2027-04-18")
    slot = project.slots.create!(label: "Teacher", schedule_item: session)
    claim = slot.slot_claims.create!(person: people(:volunteer))

    session.destroy!

    assert_nil slot.reload.schedule_item
    assert_equal claim, slot.slot_claims.sole
  end

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

  test "past Slots cannot be claimed" do
    slot = projects(:community_meal).slots.create!(date: Date.yesterday, label: "Past dinner", capacity: 1)

    assert_no_difference "SlotClaim.count" do
      assert_nil slot.claim(people(:volunteer))
    end

    assert_equal [ "This Slot has passed." ], slot.errors[:base]
  end
end
