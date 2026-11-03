require "test_helper"
require_relative "../support/method_stubs"

class OversightSummaryTest < ActiveSupport::TestCase
  include MethodStubs

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

  test "the prompt payload carries an opaque id and no name or email" do
    facts = OversightSummary.facts_for(@person, last_check_in: nil)
    prompt = OversightSummary::INSTRUCTIONS + OversightSummary.payload(facts)

    assert_includes prompt, "p1"
    assert_no_match(/#{Regexp.escape(@person.name)}/i, prompt)
    assert_no_match(/#{Regexp.escape(@person.email)}/i, prompt) if @person.email.present?
    assert_no_match(/@/, prompt)
  end

  test "a reply that quotes only the given counts and dates is kept" do
    reply = %({"sentence": "Serving on 4 Active Projects since September, no check-in logged."})

    assert_equal "Serving on 4 Active Projects since September, no check-in logged.", OversightSummary.from_reply(reply, @facts)
  end

  test "a reply with a number that was not passed in, a judgment, an address or no JSON is rejected" do
    [
      %({"sentence": "Serving on 9 Active Projects."}),
      %({"sentence": "Serving on 4 Active Projects and seems tired."}),
      %({"sentence": "Serving on 4 Active Projects, reach out to them at volunteer@example.com."}),
      %({"sentence": "#{"x" * 300}"}),
      %({"sentence": ""}),
      "Serving on 4 Active Projects."
    ].each do |reply|
      assert_raises(OversightSummary::Rejected, reply) { OversightSummary.from_reply(reply, @facts) }
    end
  end

  test "without an OpenRouter key no model call is made" do
    previous = ENV.delete("OPENROUTER_API_KEY")
    stub_method(RubyLLM, :context, ->(*) { flunk "no model call without a key" }) do
      assert_nil OversightSummary.generate(@facts)
    end
  ensure
    ENV["OPENROUTER_API_KEY"] = previous if previous
  end

  test "a cached AI sentence is shown only for the counts it was made from" do
    store = ActiveSupport::Cache::MemoryStore.new
    stub_method(Rails, :cache, -> { store }) do
      key = OversightSummary.key_for(@person, @facts)
      store.write(key, "Serving on 4 Active Projects since September, and checked in recently.")

      assert_equal "Serving on 4 Active Projects since September, and checked in recently.", OversightSummary.line(@person, @facts)

      changed = @facts.merge("serving_load" => 5)
      assert_equal OversightSummary.template(changed), OversightSummary.line(@person, changed)
    end
  end

  test "a failed generation is remembered for an hour, and the template stays" do
    store = ActiveSupport::Cache::MemoryStore.new
    stub_method(Rails, :cache, -> { store }) do
      stub_method(OversightSummary, :generate, ->(*) { nil }) do
        OversightSummaryJob.perform_now(OversightSummary.key_for(@person, @facts), @facts)
      end

      assert_equal false, store.read(OversightSummary.key_for(@person, @facts))
      assert_equal OversightSummary.template(@facts), OversightSummary.line(@person, @facts)
    end
  end
end
