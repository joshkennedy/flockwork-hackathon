require "test_helper"
require_relative "../support/method_stubs"

class OversightSummaryTest < ActiveSupport::TestCase
  include MethodStubs
  include ActiveJob::TestHelper

  setup do
    @person = people(:volunteer)
    @facts = { "serving_load" => 4, "serving_since" => "2026-09-03", "last_check_in_on" => nil }
  end

  test "the template reads from counts and dates only" do
    travel_to Date.new(2026, 11, 2) do
      assert_equal "Serving on 4 Active Projects since September, no check-in logged.", OversightSummary.template(@facts)
      assert_equal "Serving on 1 Active Project since September, last check-in Oct 28.",
        OversightSummary.template(@facts.merge("serving_load" => 1, "last_check_in_on" => "2026-10-28"))
    end
  end

  test "the template names the year only when the start is not this year" do
    travel_to Date.new(2026, 11, 2) do
      sentence = OversightSummary.template(@facts.merge("serving_since" => "2025-03-01"))

      assert_equal "Serving on 4 Active Projects since March 2025, no check-in logged.", sentence
    end
  end

  test "the line uses current facts without enqueuing AI work" do
    previous = ENV["OPENROUTER_API_KEY"]
    ENV["OPENROUTER_API_KEY"] = "configured"

    assert_no_enqueued_jobs do
      assert_equal OversightSummary.template(@facts), OversightSummary.line(@person, @facts)
      changed = @facts.merge("serving_load" => 5)
      assert_equal OversightSummary.template(changed), OversightSummary.line(@person, changed)
    end
  ensure
    ENV["OPENROUTER_API_KEY"] = previous
  end

  test "already queued jobs clear their pending marker without generating a summary" do
    store = ActiveSupport::Cache::MemoryStore.new
    key = "oversight-summary/legacy"
    store.write("#{key}/pending", true)

    stub_method(Rails, :cache, -> { store }) do
      OversightSummaryJob.perform_now(key, @facts)
      assert_nil store.read("#{key}/pending")
      assert_nil store.read(key)
    end
  end
end
