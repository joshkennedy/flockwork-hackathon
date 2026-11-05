class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access

  # Show a confirmation button instead of applying on GET, so link scanners that prefetch emails cannot use up the link.
  # Confirming never signs anyone in: it only proves the mailbox belongs to the reader.
  def show
    render :invalid, status: :unprocessable_content unless Person.find_by_token_for(:email_change, params[:token])
  end

  def create
    render :invalid, status: :unprocessable_content unless Person.confirm_email_change(params[:token])
  end
end
