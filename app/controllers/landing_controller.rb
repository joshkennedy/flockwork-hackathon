class LandingController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect_to workspace_path(Current.workspace) if authenticated?
  end
end
