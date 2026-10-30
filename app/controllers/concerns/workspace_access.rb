module WorkspaceAccess
  extend ActiveSupport::Concern

  included do
    before_action :ensure_current_workspace
  end

  private
    def ensure_current_workspace
      raise ActiveRecord::RecordNotFound unless params[:workspace_slug] == Current.workspace.slug
    end
end
