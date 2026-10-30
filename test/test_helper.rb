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

module ActiveSupport
  class TestCase
    # Rails only parallelizes suites above its test-count threshold; each worker gets its own database.
    parallelize(workers: :number_of_processors)

    fixtures :all
  end
end
