class WorkspacesController < ApplicationController
  allow_unauthenticated_access only: :create

  def show
    return redirect_to workspace_path(Current.workspace) unless params[:workspace_slug] == Current.workspace.slug

    @workspace = Current.workspace
    @person = Current.person
    @pending_invitations = Policy.visible_invitations(Current.person).includes(:project).order(created_at: :desc)
  end

  def create
    @workspace = Workspace.new(name: workspace_params[:church_name])
    @admin = @workspace.people.build(name: workspace_params[:your_name], email: workspace_params[:email], admin: true)

    if @admin.valid?(:workspace_creation) && @workspace.save
      start_new_session_for @admin
      redirect_to workspace_path(@workspace)
    else
      redirect_to root_path, alert: (@workspace.errors.full_messages + @admin.errors.full_messages).to_sentence
    end
  end

  private
    def workspace_params
      params.permit(:church_name, :your_name, :email)
    end
end
