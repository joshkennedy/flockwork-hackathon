class DemoSessionsController < ApplicationController
  allow_unauthenticated_access

  def create
    workspace = Workspace.find_by!(slug: params[:workspace_slug])
    raise ActiveRecord::RecordNotFound unless workspace.demo?

    email = DemoWorkspace::ROLE_EMAILS.fetch(params[:role]) { raise ActiveRecord::RecordNotFound }
    start_new_session_for workspace.people.find_by!(email:)
    redirect_to workspace_path(workspace)
  end
end
