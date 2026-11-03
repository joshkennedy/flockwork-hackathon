class SignInRequestsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    flash.now[:alert] = "Too many requests. Wait three minutes, then try again."
    render :new, status: :too_many_requests
  }

  def new
  end

  def check_email
  end

  # Same response whether or not the email matches a Person, so the form cannot be used to discover who is signed up.
  # One email can belong to a Person in several Organizations; the link signs in as one and OrganizationChoices offers the rest.
  def create
    email = params[:email].to_s
    person = Person.where(email:).order(:id).first if email.present?
    SignInMailer.sign_in_link(person).deliver_later if person&.can_sign_in?

    redirect_to check_email_path, status: :see_other
  rescue ActiveJob::EnqueueError
    flash.now[:alert] = "We couldn't request your sign-in email. Please try again."
    render :new, status: :service_unavailable
  end
end
