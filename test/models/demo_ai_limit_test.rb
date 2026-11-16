require "test_helper"
require_relative "../support/method_stubs"

class DemoAiLimitTest < ActiveSupport::TestCase
  include MethodStubs

  test "demo calls stop at the hourly limit" do
    organization = organizations(:grace_fellowship)

    with_cache do
      assert Array.new(DemoAiLimit::HOURLY_LIMIT) { DemoAiLimit.allow?(organization) }.all?
      assert_not DemoAiLimit.allow?(organization)
    end
  end

  test "demo calls stop at the daily limit across hourly windows" do
    organization = organizations(:grace_fellowship)

    with_cache do
      5.times do |hour|
        travel_to Time.zone.local(2026, 11, 16, hour * 2) do
          assert Array.new(DemoAiLimit::HOURLY_LIMIT) { DemoAiLimit.allow?(organization) }.all?
        end
      end

      travel_to Time.zone.local(2026, 11, 16, 10) do
        assert_not DemoAiLimit.allow?(organization)
      end
    end
  end

  test "real churches are not capped" do
    organization = organizations(:st_example)

    with_cache do
      assert Array.new(DemoAiLimit::DAILY_LIMIT + 1) { DemoAiLimit.allow?(organization) }.all?
    end
  end

  test "demo reset keeps using the same shared cap" do
    organization = organizations(:grace_fellowship)
    replacement = organization.dup
    replacement.id = organization.id + 10_000

    with_cache do
      DemoAiLimit::HOURLY_LIMIT.times { assert DemoAiLimit.allow?(organization) }
      assert_not DemoAiLimit.allow?(replacement)
    end
  end

  private
    def with_cache
      store = ActiveSupport::Cache::MemoryStore.new
      stub_method(Rails, :cache, -> { store }) { yield }
    end
end
