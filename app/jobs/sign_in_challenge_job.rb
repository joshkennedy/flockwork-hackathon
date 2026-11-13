# Makes the code here, not in the request, so the plain code is never stored in the queue.
# No retries: a retry would mail a second code, and the helper has Resend Code on the page.
class SignInChallengeJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  # One SMS segment. A longer Project name is cut so the link survives.
  SMS_LENGTH = 160

  def perform(challenge)
    code = challenge.new_code!

    if challenge.channel == "email"
      SignInMailer.code(challenge, code).deliver_now
    elsif !SmsOptOut.blocked?(challenge.address)
      Messaging::Sendly.new.send_sms(to: challenge.address, text: sms_text(challenge, code),
        idempotency_key: "sign-in-challenge-#{challenge.id}-#{challenge.code_digest.first(16)}")
    end
  end

  private
    def sms_text(challenge, code)
      url = Rails.application.routes.url_helpers.guest_sign_in_link_url(challenge.link_token,
        **Rails.application.config.action_mailer.default_url_options)
      text = "Flockwork: #{code} is your code to help with %s. Or tap: #{url}"
      text % challenge.project.name.truncate([ SMS_LENGTH - text.length + 2, 12 ].max)
    end
end
