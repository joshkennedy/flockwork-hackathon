require "test_helper"
require "yaml"

class OffsiteBackupJobTest < ActiveJob::TestCase
  test "runs every day at 4am in production" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    schedule = recurring.dig("production", "offsite_backup")

    assert_equal "OffsiteBackupJob", schedule.fetch("class")
    assert_equal "at 4am every day", schedule.fetch("schedule")
  end

  test "reports failures and re-raises them" do
    reported_errors = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) do |error, **|
      reported_errors << error
    end
    Rails.error.subscribe(subscriber)

    with_backup_environment("PATH" => "") do
      error = assert_raises(Errno::ENOENT) { OffsiteBackupJob.perform_now }
      assert_same error, reported_errors.last
    end
  ensure
    Rails.error.unsubscribe(subscriber) if subscriber
  end

  private
    def with_backup_environment(overrides)
      values = backup_env.merge(overrides)
      originals = values.to_h { |key, _value| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      originals&.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    end

    def backup_env
      {
        "BACKUP_BUCKET_NAME" => "fake-backup-bucket",
        "BACKUP_BUCKET_ENDPOINT" => "https://fake.storage.example",
        "BACKUP_BUCKET_REGION" => "auto",
        "BACKUP_BUCKET_ACCESS_KEY_ID" => "fake-access-key",
        "BACKUP_BUCKET_SECRET_ACCESS_KEY" => "fake-secret-key"
      }
    end
end
