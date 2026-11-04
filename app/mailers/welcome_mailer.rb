class WelcomeMailer < ApplicationMailer
  # No sign-in token here: those expire in 15 minutes and die at the next sign-in, so the email would outlive its link.
  def welcome(person)
    @person = person
    @organization = person.organization

    mail to: person.email, subject: "#{@organization.name} is set up on Flockwork"
  end
end
