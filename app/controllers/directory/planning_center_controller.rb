module Directory
  class PlanningCenterController < ApplicationController
    include AdminOnly
    authorize_admin_with :manage_directory_source

    def show
    end

    # OAuth is outside this demo's scope; one church connects with its personal access token.
    def update
      if Current.organization.update(connection_params.merge(pco_last_sync_result: {}, pco_last_sync_error: nil))
        redirect_to planning_center_directory_path, notice: "Planning Center settings saved."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def sync
      unless Current.organization.planning_center_connected?
        return redirect_to planning_center_directory_path, alert: "Connect Planning Center before syncing."
      end

      DirectorySyncJob.perform_later(Current.organization)
      redirect_to planning_center_directory_path, notice: "Planning Center sync started."
    end

    private
      def connection_params
        params.require(:organization).permit(:pco_app_id, :pco_secret, :pco_skills_field_id)
      end
  end
end
