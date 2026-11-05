require "test_helper"
require_relative "../support/method_stubs"

class AwaySuggestSpendTest < ActionDispatch::IntegrationTest
  include MethodStubs

  setup do
    @original_key = ENV["OPENROUTER_API_KEY"]
    ENV["OPENROUTER_API_KEY"] = "test-openrouter-key"
  end

  teardown do
    if @original_key.nil?
      ENV.delete("OPENROUTER_API_KEY")
    else
      ENV["OPENROUTER_API_KEY"] = @original_key
    end
  end

  test "suggest away is bounded per person" do
    post demo_session_path(role: "volunteer")
    calls = 0
    draft_ranges = [ { starts_on: Date.new(2026, 7, 1), ends_on: Date.new(2026, 7, 31) } ]
    parser = ->(*) {
      calls += 1
      draft_ranges
    }
    store = ActiveSupport::Cache::MemoryStore.new
    stub_method(ProfilesController.cache_store, :increment, ->(*args, **kwargs) { store.increment(*args, **kwargs) }) do
      stub_method(AwayDateParser, :call, parser) do
        20.times do
          post suggest_away_profile_path, params: { away_text: "Away in July" }
          assert_response :success
        end
        post suggest_away_profile_path, params: { away_text: "Away again" }
        assert_response :too_many_requests
        assert_equal 20, calls
      end
    end
  end
end
