require "test_helper"
require_relative "../support/method_stubs"

class AwayDateParserTest < ActiveSupport::TestCase
  include MethodStubs

  test "a reply with ranges becomes date ranges" do
    ranges = AwayDateParser.from_reply(%({"ranges": [{"starts_on": "2026-07-01", "ends_on": "2026-07-31"}], "unclear": false}))

    assert_equal [ { starts_on: Date.new(2026, 7, 1), ends_on: Date.new(2026, 7, 31) } ], ranges
  end

  test "a reply with no clear dates is unavailable, not an empty success" do
    assert_raises(AwayDateParser::Unavailable) do
      AwayDateParser.from_reply(%({"ranges": [], "unclear": true}))
    end
  end

  test "a range that ends before it starts, bad dates or prose-only replies are unavailable" do
    [
      %({"ranges": [{"starts_on": "2026-07-31", "ends_on": "2026-07-01"}]}),
      %({"ranges": [{"starts_on": "July", "ends_on": "2026-07-31"}]}),
      %({"ranges": [{"starts_on": "2026-07-01"}]}),
      "Sorry, I cannot help with that."
    ].each do |reply|
      assert_raises(AwayDateParser::Unavailable, reply) { AwayDateParser.from_reply(reply) }
    end
  end

  test "without an OpenRouter key the parser is unavailable and never calls a model" do
    previous = ENV.delete("OPENROUTER_API_KEY")
    stub_method(RubyLLM, :context, ->(*) { flunk "no model call without a key" }) do
      assert_raises(AwayDateParser::Unavailable) { AwayDateParser.call("Away in March") }
    end
  ensure
    ENV["OPENROUTER_API_KEY"] = previous if previous
  end

  test "a provider error or timeout is unavailable, so the manual fields still work" do
    previous = ENV["OPENROUTER_API_KEY"]
    ENV["OPENROUTER_API_KEY"] = "test-key"
    stub_method(RubyLLM, :context, ->(*) { raise Timeout::Error, "slow" }) do
      assert_raises(AwayDateParser::Unavailable) { AwayDateParser.call("Away in March") }
    end
  ensure
    previous ? ENV["OPENROUTER_API_KEY"] = previous : ENV.delete("OPENROUTER_API_KEY")
  end
end
