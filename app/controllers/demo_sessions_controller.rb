class DemoSessionsController < ApplicationController
  allow_unauthenticated_access

  def new
  end

  def create
    workspace = Workspace.find_by!(slug: DemoWorkspace::SLUG, demo: true)
    email = DemoWorkspace::ROLE_EMAILS.fetch(params[:role]) { raise ActiveRecord::RecordNotFound }
    start_new_session_for workspace.people.find_by!(email:)
    redirect_to home_path
  end
end
