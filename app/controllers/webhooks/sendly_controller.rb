module Webhooks
  class SendlyController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    TOLERANCE = 300

    # Payload per sendly.live/llms.txt "Webhook Payload Structure":
    # { "id": "evt_...", "created": 1737283800 (unix seconds), "type": "message.opt_out" | "message.opt_in",
    #   "data": { "object": { "from": "+1...", "to": "+1..." } } }
    # For an inbound STOP/START, "from" is the subscriber and "to" is our number.
    def create
      return head :unauthorized unless valid_signature?

      event = JSON.parse(request.raw_post)
      id, type = event["id"].to_s, event["type"].to_s
      phone = event.dig("data", "object", "from") if event["data"].is_a?(Hash) && event["data"]["object"].is_a?(Hash)
      created = event["created"]
      return head :unprocessable_entity if id.empty? || phone.blank? || !created.is_a?(Integer) || %w[message.opt_out message.opt_in].exclude?(type)

      SmsOptOut.transaction do
        SmsWebhookEvent.create!(event_id: id)
        at = Time.at(created).utc
        type == "message.opt_out" ? SmsOptOut.opt_out!(phone, at:) : SmsOptOut.opt_in!(phone, at:)
      end
      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue ActiveRecord::RecordNotUnique
      head :ok
    end

    private
      def valid_signature?
        secret = ENV["SENDLY_WEBHOOK_SECRET"].to_s
        timestamp = request.headers["X-Sendly-Timestamp"].to_s
        return false if secret.empty? || !timestamp.match?(/\A\d+\z/) || (Time.current.to_i - timestamp.to_i).abs > TOLERANCE

        expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{request.raw_post}")}"
        ActiveSupport::SecurityUtils.secure_compare(expected, request.headers["X-Sendly-Signature"].to_s)
      end
  end
end
