require "test_helper"

class SlotConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    @slot&.notifications&.delete_all
    @slot&.slot_claims&.delete_all
    @slot&.delete
    @membership&.delete
  end

  test "two simultaneous claims for the last place allow exactly one claim" do
    project = projects(:community_meal)
    @membership = project.memberships.create!(person: people(:other_volunteer), role: :volunteer)
    @slot = project.slots.create!(date: "2027-02-15", label: "Bring dinner", capacity: 1)
    person_ids = [ people(:volunteer).id, people(:other_volunteer).id ]
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = person_ids.map do |person_id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          slot = project.slots.find(@slot.id)
          person = project.people.find(person_id)
          results << slot.claim(person)&.persisted?
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)

    assert_equal 1, 2.times.count { results.pop }
    assert_equal 1, @slot.slot_claims.count
    assert_equal 1, @slot.reload.claims_count
  end
end
