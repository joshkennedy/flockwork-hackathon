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
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelpers
end
