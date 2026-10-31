class DirectorySyncJob < ApplicationJob
  def perform(organization)
    source = DirectorySources::PlanningCenter.new(
      app_id: organization.pco_app_id,
      secret: organization.pco_secret
    )
    result = DirectorySync.new(organization, source).call
    organization.update!(
      pco_last_synced_at: Time.current,
      pco_last_sync_result: result,
      pco_last_sync_error: nil
    )
  rescue DirectorySources::Error => error
    organization.update!(pco_last_sync_result: {}, pco_last_sync_error: error.message)
  end
end
