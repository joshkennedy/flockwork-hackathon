# Preview at /rails/mailers/sign_in_mailer
class SignInMailerPreview < ActionMailer::Preview
  def sign_in_link
    SignInMailer.sign_in_link(Person.where.not(email: nil).first!)
  end
end
