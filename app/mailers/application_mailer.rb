class ApplicationMailer < ActionMailer::Base
  default from: "Flockwork <hello@getflockwork.com>", "MESSAGE-STREAM" => "outbound"
  layout "mailer"
  helper MailerHelper
end
