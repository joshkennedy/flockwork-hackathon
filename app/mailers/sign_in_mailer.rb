class SignInMailer < ApplicationMailer
  def sign_in_link(person)
    @person = person
    @url = sign_in_link_url(person.generate_token_for(:sign_in))

    mail to: person.email, subject: "Your Flockwork sign-in link"
  end

  # The code is typed on the page the helper left open; the button signs in whichever browser opens the email.
  def code(challenge, code)
    @code = code
    @project = challenge.project
    @url = guest_sign_in_link_url(challenge.link_token)

    mail to: challenge.address, subject: "#{code} is your Flockwork code"
  end

  # Goes to the address being claimed, so only its mailbox owner can make it the Person's sign-in email.
  def email_change(person)
    @person = person
    @url = email_confirmation_url(person.generate_token_for(:email_change))

    mail to: person.pending_email, subject: "Confirm your email for Flockwork"
  end
end
