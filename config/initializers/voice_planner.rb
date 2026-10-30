Rails.application.config.after_initialize do
  Rails.configuration.x.voice_client_secret_minter = Planner::VoiceClientSecretMinter.new
end
