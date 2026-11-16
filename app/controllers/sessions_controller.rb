class SessionsController < ApplicationController
  def destroy
    terminate_session
    redirect_to safe_return_path, status: :see_other
  end

  private
    def safe_return_path
      path = params[:return_to].to_s
      path.start_with?("/") && !path.start_with?("//") ? path : root_path
    end
end
