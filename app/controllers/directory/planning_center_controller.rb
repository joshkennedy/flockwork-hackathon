module Directory
  class PlanningCenterController < ApplicationController
    include AdminOnly
    include SettingsPage
    authorize_admin_with :manage_directory_source

    # OAuth is outside this demo's scope; one church connects with its personal access token.
    def update
      attributes = connection_params
      verify_credentials!(attributes[:pco_app_id], attributes[:pco_secret]) if attributes.key?(:pco_app_id) || attributes.key?(:pco_secret)

      if Current.organization.update(attributes.merge(pco_last_sync_result: {}, pco_last_sync_error: nil))
        redirect_to settings_tab_path("directory"), notice: "Planning Center settings saved."
      else
        render_settings("directory", status: :unprocessable_entity)
      end
    rescue DirectorySources::Error => error
      Current.organization.errors.add(:base, error.message)
      render_settings("directory", status: :unprocessable_entity)
    end

    def sync
      unless Current.organization.planning_center_connected?
        return redirect_to settings_tab_path("directory"), alert: "Connect Planning Center before syncing."
      end

      verify_credentials!(Current.organization.pco_app_id, Current.organization.pco_secret)
      DirectorySyncJob.perform_later(Current.organization)
      redirect_to settings_tab_path("directory"), notice: "Planning Center sync started."
    rescue DirectorySources::Error => error
      Current.organization.update!(pco_last_sync_result: {}, pco_last_sync_error: error.message)
      render_settings("directory", status: :unprocessable_entity)
    end

    private
      def verify_credentials!(app_id, secret)
        DirectorySources::PlanningCenter.new(
          app_id:,
          secret:
        ).verify_credentials!
      end

      def connection_params
        params.require(:organization).permit(:pco_app_id, :pco_secret, :pco_skills_field_id)
      end
  end
end
