class DemoSessionsController < ApplicationController
  allow_unauthenticated_access

  def new
  end

  def create
    organization = Organization.find_by!(slug: DemoOrganization::SLUG, demo: true)
    email = DemoOrganization::ROLE_EMAILS.fetch(params[:role]) { raise ActiveRecord::RecordNotFound }
    start_new_session_for organization.people.active.find_by!(email:), auth_method: "demo"
    redirect_to home_path
  end
end
