RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  config.xai_api_key = ENV["XAI_API_KEY"]
  config.request_timeout = 30
  config.logger = Rails.logger
end
