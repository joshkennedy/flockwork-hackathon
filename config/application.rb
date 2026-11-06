require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

if defined?(Dotenv) && (Rails.env.development? || Rails.env.test?)
  environment = Rails.env
  paths = [ ".env.#{environment}.local", (".env.local" unless environment == "test"), ".env.#{environment}", ".env" ]
  Dotenv.load(*paths.compact.map { |path| File.expand_path("../#{path}", __dir__) })
end

module Flockwork
  class Application < Rails::Application
    config.load_defaults 8.1

    # Parallel tickets use coordinated migration versions that can be later than a developer's local clock.
    config.active_record.validate_migration_timestamps = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Rails also serves application/pdf inline by its claimed type; only images are inline here.
    config.active_storage.content_types_allowed_inline = ActiveStorage::Engine.config.active_storage.content_types_allowed_inline - %w[application/pdf]
  end
end
