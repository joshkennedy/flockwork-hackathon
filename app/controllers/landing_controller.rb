class LandingController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect_to home_path if authenticated?
  end

  def sitemap
  end

  def llms
    render formats: :text, content_type: "text/plain"
  end
end
