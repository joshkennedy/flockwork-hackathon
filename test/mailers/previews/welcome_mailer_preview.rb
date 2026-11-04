# Preview at /rails/mailers/welcome_mailer
class WelcomeMailerPreview < ActionMailer::Preview
  def welcome
    WelcomeMailer.welcome(Person.where(admin: true).where.not(email: nil).first!)
  end
end
