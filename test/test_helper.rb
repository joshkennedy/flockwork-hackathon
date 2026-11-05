ENV["RAILS_ENV"] ||= "test"

require "testcontainers/postgres"

# Starts Postgres before Rails loads so config/database.yml picks up DATABASE_URL.
postgres = Testcontainers::PostgresContainer.new("postgres:18")
postgres.start
ENV["DATABASE_URL"] = postgres.database_url
main_pid = Process.pid
at_exit { (postgres.stop; postgres.remove) if Process.pid == main_pid }

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/vcr"
require_relative "support/sign_in_helpers"

module ActiveSupport
  class TestCase
    # Serial on purpose: with pg 1.7.0 on macOS arm64, forked test workers segfault even against a plain local
    # Postgres. Raise the worker count again once the suite is verified in parallel on Linux CI.
    parallelize(workers: 1)

    fixtures :all

    # A banner as it looks once admission and the variants job are done.
    def attach_ready_banner(project, fixture: "banner_wide.jpg", content_type: "image/jpeg")
      project.banner.attach(io: file_fixture(fixture).open, filename: fixture, content_type: content_type)
      project.banner.blob.analyze
      ProjectBannerVariantsJob.perform_now(project.reload)
      project.reload
    end
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelpers
end
