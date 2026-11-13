module Directory
  class PlanningCenterController < ApplicationController
    include AdminOnly
    include SettingsPage
    authorize_admin_with :manage_directory_source

    # OAuth is outside this demo's scope; one church connects with its personal access token.
    def update
      if Current.organization.update(connection_params.merge(pco_last_sync_result: {}, pco_last_sync_error: nil))
        redirect_to settings_tab_path("directory"), notice: "Planning Center settings saved."
      else
        render_settings("directory", status: :unprocessable_entity)
      end
    end

    def sync
      unless Current.organization.planning_center_connected?
        return redirect_to settings_tab_path("directory"), alert: "Connect Planning Center before syncing."
      end

      DirectorySyncJob.perform_later(Current.organization)
      redirect_to settings_tab_path("directory"), notice: "Planning Center sync started."
    end

    private
      def connection_params
        params.require(:organization).permit(:pco_app_id, :pco_secret, :pco_skills_field_id)
      end
  end
end
