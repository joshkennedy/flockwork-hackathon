class InvitationSignInSmsJob < ApplicationJob
  retry_on Messaging::Sendly::RetryableError, wait: 30.seconds, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(organization, person_id, token)
    person = organization.people.find(person_id)
    Messaging::Sendly.new.send_sms(
      to: person.phone,
      text: "Your Flockwork sign-in link: #{sign_in_link_url(token)}",
      idempotency_key: "invitation-sign-in-#{Digest::SHA256.hexdigest(token)}"
    )
  rescue Messaging::Sendly::Error => error
    Rails.logger.warn("Invitation sign-in SMS failed for Person #{person_id}: #{error.class}: #{error.message}")
    raise
  rescue ArgumentError
    Rails.logger.warn("Invitation sign-in SMS failed for Person #{person_id}: invalid SMS payload")
  end

  private
    def sign_in_link_url(token)
      Rails.application.routes.url_helpers.sign_in_link_url(
        token,
        **Rails.application.config.action_mailer.default_url_options
      )
    end
end
