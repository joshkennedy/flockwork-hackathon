class DirectorySyncJob < ApplicationJob
  def perform(workspace)
    source = DirectorySources::PlanningCenter.new(
      app_id: workspace.pco_app_id,
      secret: workspace.pco_secret
    )
    result = DirectorySync.new(workspace, source).call
    workspace.update!(
      pco_last_synced_at: Time.current,
      pco_last_sync_result: result,
      pco_last_sync_error: nil
    )
  rescue DirectorySources::Error => error
    workspace.update!(pco_last_sync_result: {}, pco_last_sync_error: error.message)
  end
end
