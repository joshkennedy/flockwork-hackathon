class LandingController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect_to home_path if authenticated?
  end
end
