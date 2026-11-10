require "test_helper"
require "aws-sdk-s3"

class OffsiteBackupTest < ActiveSupport::TestCase
  Status = Data.define(:success?)

  setup do
    @created_blobs = []
  end

  teardown do
    @created_blobs.each { |blob| blob.service.delete(blob.key) }
  end

  test "does nothing when the backup bucket is not configured" do
    backup = OffsiteBackup.new(
      env: {},
      client_builder: -> { flunk "built an S3 client" },
      dump_runner: ->(*) { flunk "ran pg_dump" }
    )

    assert_nil backup.call
  end

  test "raises on a failed database dump without uploading and removes the temp file" do
    temp_path = nil
    client = Aws::S3::Client.new(stub_responses: true)
    dump_runner = lambda do |_pg_env, _argv, tempfile|
      temp_path = tempfile.path
      [ "server version mismatch", Status.new(false) ]
    end

    error = assert_raises(OffsiteBackup::DumpError) do
      build_backup(client:, dump_runner:).call
    end

    assert_equal "pg_dump failed: server version mismatch", error.message
    assert_not File.exist?(temp_path)
    assert_empty client.api_requests.select { |request| request.fetch(:operation_name) == :put_object }
  end

  test "uploads the database and only disk blobs missing from the bucket" do
    existing_blob = create_blob("already-backed-up.txt", "already there")
    new_blob = create_blob("new.txt", "stream this file")
    missing_blob = create_missing_blob("missing.txt")
    client = Aws::S3::Client.new(stub_responses: true)
    client.stub_responses(:list_objects_v2, [
      {
        contents: [ { key: "storage/#{existing_blob.key}" } ],
        is_truncated: true,
        next_continuation_token: "storage-page-2"
      },
      { contents: [], is_truncated: false },
      { contents: [], is_truncated: false }
    ])
    client_options = nil
    invocation = {}
    log_output = StringIO.new
    dump_runner = lambda do |pg_env, argv, tempfile|
      invocation[:pg_env] = pg_env
      invocation[:argv] = argv
      tempfile.write("custom-format-dump")
      [ "", Status.new(true) ]
    end

    build_backup(
      client:,
      dump_runner:,
      client_builder: ->(**options) { client_options = options; client },
      logger: ActiveSupport::Logger.new(log_output)
    ).call

    put_requests = client.api_requests.select { |request| request.fetch(:operation_name) == :put_object }
    assert_equal [
      "db/2026-11-10T04-00-00Z.dump",
      "storage/#{new_blob.key}"
    ], put_requests.map { |request| request.dig(:params, :key) }
    assert put_requests.all? { |request| request.dig(:params, :body).respond_to?(:read) }
    assert_includes log_output.string, missing_blob.key

    list_requests = client.api_requests.select { |request| request.fetch(:operation_name) == :list_objects_v2 }
    assert_equal [ "storage/", "storage/", "db/" ], list_requests.map { |request| request.dig(:params, :prefix) }
    assert_equal "storage-page-2", list_requests.second.dig(:params, :continuation_token)

    assert_equal [ "pg_dump", "--format=custom" ], invocation.fetch(:argv)
    assert_equal "fake-database-password", invocation.dig(:pg_env, "PGPASSWORD")
    refute_includes invocation.fetch(:argv), "fake-database-password"
    refute_includes log_output.string, "fake-database-password"

    assert_equal "https://fake.storage.example", client_options.fetch(:endpoint)
    assert_equal "auto", client_options.fetch(:region)
    assert_equal false, client_options.fetch(:force_path_style)
    assert_equal "when_required", client_options.fetch(:request_checksum_calculation)
    assert_equal "when_required", client_options.fetch(:response_checksum_validation)
  end

  test "keeps the seven newest database dumps even when all dumps are old" do
    client = pruning_client((20..29).map do |days_old|
      s3_object("db/#{days_old}.dump", days_old.days.ago)
    end)

    build_backup(client:, dump_runner: successful_dump_runner).call

    assert_equal [ "db/27.dump", "db/28.dump", "db/29.dump" ], deleted_keys(client).sort
  end

  test "never deletes recent dumps or objects outside the database dump prefix" do
    objects = (1..8).map { |days_old| s3_object("db/recent-#{days_old}.dump", days_old.days.ago) }
    objects << s3_object("db/old.dump", 20.days.ago)
    objects << s3_object("db/notes.txt", 30.days.ago)
    objects << s3_object("storage/never-delete", 30.days.ago)
    client = pruning_client(objects)

    build_backup(client:, dump_runner: successful_dump_runner).call

    assert_equal [ "db/old.dump" ], deleted_keys(client)
  end

  private
    def build_backup(client:, dump_runner:, client_builder: ->(**) { client }, logger: Rails.logger)
      OffsiteBackup.new(
        env: backup_env,
        client_builder:,
        dump_runner:,
        logger:,
        now: Time.utc(2026, 11, 10, 4),
        connection_config: {
          host: "db.internal",
          port: 5432,
          username: "flockwork",
          password: "fake-database-password",
          database: "flockwork_production"
        }
      )
    end

    def create_blob(filename, contents)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(contents),
        filename:,
        content_type: "text/plain"
      ).tap { |blob| @created_blobs << blob }
    end

    def create_missing_blob(filename)
      ActiveStorage::Blob.create_before_direct_upload!(
        filename:,
        byte_size: 7,
        checksum: "ZmFrZQ==",
        content_type: "text/plain"
      ).tap { |blob| @created_blobs << blob }
    end

    def pruning_client(database_objects)
      Aws::S3::Client.new(stub_responses: true).tap do |client|
        client.stub_responses(:list_objects_v2, [
          { contents: [], is_truncated: false },
          { contents: database_objects, is_truncated: false }
        ])
      end
    end

    def s3_object(key, last_modified)
      { key:, last_modified:, size: 100 }
    end

    def successful_dump_runner
      lambda do |_pg_env, _argv, tempfile|
        tempfile.write("custom-format-dump")
        [ "", Status.new(true) ]
      end
    end

    def deleted_keys(client)
      client.api_requests.filter_map do |request|
        request.dig(:params, :key) if request.fetch(:operation_name) == :delete_object
      end
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
