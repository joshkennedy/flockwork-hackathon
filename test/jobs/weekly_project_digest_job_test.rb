require "test_helper"
require_relative "../support/method_stubs"

class WeeklyProjectDigestJobTest < ActiveSupport::TestCase
  include MethodStubs

  setup do
    ActionMailer::Base.deliveries.clear
    @store = ActiveSupport::Cache::MemoryStore.new
  end

  test "one digest per current Leader and Project each week, including retries" do
    stub_method(Rails, :cache, -> { @store }) do
      WeeklyProjectDigestJob.perform_now
      assert_equal 4, ActionMailer::Base.deliveries.size
      WeeklyProjectDigestJob.perform_now
      assert_equal 4, ActionMailer::Base.deliveries.size
      travel 1.week do
        WeeklyProjectDigestJob.perform_now
        assert_equal 8, ActionMailer::Base.deliveries.size
      end
    end
  end

  test "a retry skips deliveries completed before a later recipient failed" do
    original = ProjectDigestMailer.method(:weekly)
    calls = 0
    stub_method(Rails, :cache, -> { @store }) do
      stub_method(ProjectDigestMailer, :weekly, ->(*args) {
        calls += 1
        raise "mail service unavailable" if calls == 2
        original.call(*args)
      }) do
        assert_raises(RuntimeError) { WeeklyProjectDigestJob.perform_now }
        assert_equal 1, ActionMailer::Base.deliveries.size
        WeeklyProjectDigestJob.perform_now
        assert_equal 4, ActionMailer::Base.deliveries.size
      end
    end
  end

  test "inactive demo former Leaders missing email and opted-out people receive no digest" do
    projects(:building_cleanup).update!(archived_at: Time.current)
    projects(:outsider_project).update!(done_at: Time.current)
    projects(:community_meal).memberships.find_by!(person: people(:other_leader)).destroy!
    people(:leader).update!(email_preferences: { "weekly_project_digest" => false })
    demo = organizations(:grace_fellowship).projects.create!(name: "Demo", owner: people(:grace_leader))
    demo.memberships.create!(person: people(:grace_leader), role: :leader)
    projects(:community_meal).memberships.create!(person: people(:recipient), role: :leader)

    stub_method(Rails, :cache, -> { @store }) do
      WeeklyProjectDigestJob.perform_now
      assert_empty ActionMailer::Base.deliveries
    end
  end
end
