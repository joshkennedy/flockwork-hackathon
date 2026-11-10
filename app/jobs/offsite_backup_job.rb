class OffsiteBackupJob < ApplicationJob
  def perform
    OffsiteBackup.new.call
  rescue => error
    Rails.error.report(error, handled: false)
    raise
  end
end
