module Webhooks
  class SendlyController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    TOLERANCE = 300

    # Assumed payload: { "id": "evt_...", "type": "message.opt_out" | "message.opt_in",
    #                    "data": { "from" | "phone_number" | "to": "+1..." } }
    # For STOP/START the number that replied is the sender; "to" is our own number, so it is tried last.
    def create
      return head :unauthorized unless valid_signature?

      event = JSON.parse(request.raw_post)
      id, type = event["id"].to_s, event["type"].to_s
      data = event["data"].is_a?(Hash) ? event["data"] : {}
      phone = data["from"] || data["phone_number"] || data["phone"] || data["to"]
      return head :unprocessable_entity if id.empty? || phone.blank? || %w[message.opt_out message.opt_in].exclude?(type)

      SmsOptOut.transaction do
        SmsWebhookEvent.create!(event_id: id)
        type == "message.opt_out" ? SmsOptOut.opt_out!(phone) : SmsOptOut.opt_in!(phone)
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
