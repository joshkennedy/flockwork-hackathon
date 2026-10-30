class SignInMailer < ApplicationMailer
  def sign_in_link(person)
    @person = person
    @url = sign_in_link_url(person.generate_token_for(:sign_in))

    mail to: person.email, subject: "Your Flockwork sign-in link"
  end
end
