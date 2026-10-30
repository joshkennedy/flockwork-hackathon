class SignInRequestsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_workspace
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { head :too_many_requests }

  def new
  end

  # Same response whether or not the email matches a Person, so the form cannot be used to discover who is in a Workspace.
  def create
    email = params[:email].to_s
    person = @workspace.people.find_by(email:) if email.present?
    SignInMailer.sign_in_link(person).deliver_later if person&.can_sign_in?

    render :check_email
  end

  private
    def set_workspace
      @workspace = Workspace.find_by!(slug: params[:workspace_slug])
    end
end
