module Directory
  class PlanningCenterController < ApplicationController
    include WorkspaceAccess
    include AdminOnly
    authorize_admin_with :manage_directory_source

    def show
    end

    # OAuth is outside this demo's scope; one church connects with its personal access token.
    def update
      if Current.workspace.update(connection_params.merge(pco_last_sync_result: {}, pco_last_sync_error: nil))
        redirect_to planning_center_directory_path(Current.workspace), notice: "Planning Center connected."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def sync
      unless Current.workspace.planning_center_connected?
        return redirect_to planning_center_directory_path(Current.workspace), alert: "Connect Planning Center before syncing."
      end

      DirectorySyncJob.perform_later(Current.workspace)
      redirect_to planning_center_directory_path(Current.workspace), notice: "Planning Center sync started."
    end

    private
      def connection_params
        params.require(:workspace).permit(:pco_app_id, :pco_secret)
      end
  end
end
