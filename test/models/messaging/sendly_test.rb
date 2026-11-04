require "test_helper"

class Messaging::SendlyTest < ActiveSupport::TestCase
  test "sends SMS with authentication and a stable idempotency key" do
    request = stub_request(:post, Messaging::Sendly::ENDPOINT.to_s)
      .with(headers: { "Authorization" => "Bearer sandbox", "Idempotency-Key" => "notice-1" },
        body: { to: "+15005550000", text: "Test", messageType: "transactional" }.to_json)
      .to_return(status: 201, body: { id: "msg_test", status: "queued" }.to_json)
    result = Messaging::Sendly.new(api_key: "sandbox").send_sms(
      to: "+15005550000", text: "Test", idempotency_key: "notice-1")
    assert_equal "msg_test", result.fetch("id")
    assert_requested request
  end

  test "rejects missing credentials before sending" do
    assert_raises(Messaging::Sendly::Error) do
      Messaging::Sendly.new(api_key: nil).send_sms(to: "+15005550000", text: "Test", idempotency_key: "1")
    end
  end

  test "uses sandbox credentials unless primary credentials are present" do
    previous = ENV.to_h.slice("SENDLY_API_KEY", "SENDLY_SANDBOX_API_KEY")
    ENV["SENDLY_SANDBOX_API_KEY"] = "sandbox"

    [ [ nil, "sandbox" ], [ " ", "sandbox" ], [ "primary", "primary" ] ].each do |primary, expected|
      primary.nil? ? ENV.delete("SENDLY_API_KEY") : ENV["SENDLY_API_KEY"] = primary
      request = stub_request(:post, Messaging::Sendly::ENDPOINT.to_s)
        .with(headers: { "Authorization" => "Bearer #{expected}" })
        .to_return(status: 201, body: { id: "msg_test", status: "queued" }.to_json)

      Messaging::Sendly.new.send_sms(to: "+15005550000", text: "Test", idempotency_key: "notice-1")
      assert_requested request
      WebMock.reset!
    end
  ensure
    %w[SENDLY_API_KEY SENDLY_SANDBOX_API_KEY].each do |key|
      previous.key?(key) ? ENV[key] = previous.fetch(key) : ENV.delete(key)
    end
  end

  test "does not expose provider response bodies in errors" do
    stub_request(:post, Messaging::Sendly::ENDPOINT.to_s).to_return(status: 429, body: "private details")
    error = assert_raises(Messaging::Sendly::Error) do
      Messaging::Sendly.new(api_key: "sandbox").send_sms(to: "+15005550000", text: "Test", idempotency_key: "1")
    end
    assert_equal "Sendly request failed (HTTP 429)", error.message
  end

  test "preserves simulation and delivery failure information" do
    response = { id: "msg_test", status: "failed", simulated: true, error: "Invalid phone number" }
    stub_request(:post, Messaging::Sendly::ENDPOINT.to_s).to_return(status: 201, body: response.to_json)

    assert_equal response.stringify_keys, send_message
  end

  test "allows an explicitly classified marketing message" do
    request = stub_request(:post, Messaging::Sendly::ENDPOINT.to_s)
      .with(body: { to: "+15005550000", text: "Test", messageType: "marketing" }.to_json)
      .to_return(status: 201, body: { id: "msg_test", status: "queued" }.to_json)

    send_message(message_type: "marketing")
    assert_requested request
  end

  test "rejects invalid input before making a request" do
    [ { to: "202-555-0100" }, { to: "+0123456789" }, { to: "+1234567890123456" },
      { text: " " }, { text: 123 }, { idempotency_key: " " }, { idempotency_key: "a" * 256 },
      { idempotency_key: "key\r\nInjected: header" }, { idempotency_key: "caf\u00e9" },
      { message_type: "unknown" } ].each do |attributes|
      assert_raises(ArgumentError) { send_message(**attributes) }
    end
    assert_not_requested :post, Messaging::Sendly::ENDPOINT.to_s
  end

  test "rejects malformed provider responses without exposing their contents" do
    [ "private invalid JSON", "null", "[]", '{"private":"details"}', '{"id":"msg_test","status":null}' ].each do |body|
      stub_request(:post, Messaging::Sendly::ENDPOINT.to_s).to_return(status: 201, body: body)
      error = assert_raises(Messaging::Sendly::Error) { send_message }
      assert_match(/Sendly returned (invalid JSON|an invalid message)/, error.message)
      assert_nil error.cause
    end
  end

  test "reports ambiguous delivery after a timeout without retrying" do
    request = stub_request(:post, Messaging::Sendly::ENDPOINT.to_s).to_timeout

    error = assert_raises(Messaging::Sendly::Error) { send_message }
    assert_includes error.message, "delivery is unknown"
    assert_includes error.message, "same idempotency key"
    assert_nil error.cause
    assert_requested request, times: 1
  end

  test "wraps network errors without exposing their details" do
    request = stub_request(:post, Messaging::Sendly::ENDPOINT.to_s).to_raise(SocketError.new("private details"))

    error = assert_raises(Messaging::Sendly::Error) { send_message }
    assert_not_includes error.message, "private details"
    assert_nil error.cause
    assert_requested request, times: 1
  end

  private
    def send_message(**attributes)
      Messaging::Sendly.new(api_key: "sandbox").send_sms(
        **{ to: "+15005550000", text: "Test", idempotency_key: "notice-1" }.merge(attributes))
    end
end
