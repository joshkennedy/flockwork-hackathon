# Development only: Messaging::Sendly hands texts here so they show in the local inbox beside email.
class SmsInboxMailer < ApplicationMailer
  def sms(to:, text:)
    mail(to: "sms-#{to}@sms.localhost", subject: "SMS to #{to}") { |format| format.text { render plain: text } }
  end
end
