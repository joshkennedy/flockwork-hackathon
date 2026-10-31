class SignInLinksController < ApplicationController
  allow_unauthenticated_access

  # Show a confirmation button instead of consuming on GET, so link scanners that prefetch emails cannot use up the link.
  def show
    render :invalid, status: :unprocessable_content unless Person.find_by_token_for(:sign_in, params[:token])
  end

  def create
    person = Person.sign_in_with_token(params[:token])

    if person
      start_new_session_for person
      redirect_to Person.where(email: person.email).many? ? new_organization_choice_path : home_path
    else
      render :invalid, status: :unprocessable_content
    end
  end
end
