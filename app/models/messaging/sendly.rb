require "net/http"
require "json"

module Messaging
  class Sendly
    class Error < StandardError; end
    class RetryableError < Error; end

    ENDPOINT = URI("https://sendly.live/api/v1/messages").freeze

    def initialize(api_key: ENV["SENDLY_API_KEY"].presence || ENV["SENDLY_SANDBOX_API_KEY"])
      @api_key = api_key.to_s.strip
    end

    def send_sms(to:, text:, idempotency_key:, message_type: "transactional")
      raise Error, "SENDLY_API_KEY is missing" if @api_key.empty?
      raise ArgumentError, "Use an E.164 phone number" unless to.is_a?(String) && /\A\+[1-9]\d{6,14}\z/.match?(to)
      raise ArgumentError, "Text is required" unless text.is_a?(String) && !text.strip.empty?
      raise ArgumentError, "Idempotency key is required" if idempotency_key.to_s.strip.empty?
      raise ArgumentError, "Use 1 to 255 printable ASCII characters for the idempotency key" unless idempotency_key.is_a?(String) && /\A[\x20-\x7E]{1,255}\z/.match?(idempotency_key)
      raise ArgumentError, "Use transactional or marketing for the message type" unless %w[transactional marketing].include?(message_type)

      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Idempotency-Key"] = idempotency_key
      request.body = JSON.generate(to: to, text: text, messageType: message_type)
      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true,
        open_timeout: 5, read_timeout: 15, write_timeout: 15) { |http| http.request(request) }
      unless response.is_a?(Net::HTTPSuccess)
        error = response.code.to_i == 429 || response.code.to_i >= 500 ? RetryableError : Error
        raise error, "Sendly request failed (HTTP #{response.code})"
      end

      result = JSON.parse(response.body)
      raise RetryableError, "Sendly returned an invalid message" unless result.is_a?(Hash) && result["id"].is_a?(String) && !result["id"].empty? && result["status"].is_a?(String) && !result["status"].empty?

      result
    rescue JSON::ParserError
      raise RetryableError, "Sendly returned invalid JSON", cause: nil
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise RetryableError, "Sendly connection failed; delivery is unknown. Retry with the same idempotency key", cause: nil
    end
  end
end
