require "aws-sdk-s3"
require "open3"
require "set"
require "tempfile"

class OffsiteBackup
  class DumpError < StandardError; end

  ENV_KEYS = %w[
    BACKUP_BUCKET_NAME
    BACKUP_BUCKET_ENDPOINT
    BACKUP_BUCKET_REGION
    BACKUP_BUCKET_ACCESS_KEY_ID
    BACKUP_BUCKET_SECRET_ACCESS_KEY
  ].freeze

  def initialize(env: ENV, client_builder: nil, dump_runner: nil, connection_config: nil, logger: Rails.logger, now: Time.now.utc)
    @env = env
    @client_builder = client_builder || ->(**options) { Aws::S3::Client.new(**options) }
    @dump_runner = dump_runner || method(:run_pg_dump)
    @connection_config = connection_config
    @logger = logger
    @now = now.utc
  end

  def call
    return unless configured?

    with_database_dump do |tempfile|
      upload_database(tempfile)
      upload_missing_blobs
      prune_database_dumps
    end
  end

  private
    attr_reader :env, :dump_runner, :logger, :now

    def configured?
      ENV_KEYS.all? { |key| env[key].present? }
    end

    def upload_database(tempfile)
      client.put_object(
        bucket: bucket_name,
        key: "db/#{now.strftime("%Y-%m-%dT%H-%M-%SZ")}.dump",
        body: tempfile
      )
    end

    def upload_missing_blobs
      existing_keys = list_objects("storage/").map(&:key).to_set

      disk_blobs.find_each do |blob|
        object_key = "storage/#{blob.key}"
        next if existing_keys.include?(object_key)

        File.open(blob.service.path_for(blob.key), "rb") do |file|
          client.put_object(bucket: bucket_name, key: object_key, body: file)
        end
      rescue Errno::ENOENT
        logger.warn("Off-site backup skipped missing Active Storage file for blob #{blob.id} (#{blob.key})")
      end
    end

    def disk_blobs
      ActiveStorage::Blob.services
      configurations = Rails.application.config.active_storage.service_configurations
      disk_services = configurations.filter_map do |name, config|
        name if config.fetch("service") == "Disk"
      end
      ActiveStorage::Blob.where(service_name: disk_services)
    end

    def prune_database_dumps
      dumps = list_objects("db/").select { |object| object.key.match?(%r{\Adb/.+\.dump\z}) }
      kept_keys = dumps.sort_by(&:last_modified).reverse.first(7).map(&:key).to_set
      cutoff = now - 14.days

      dumps.each do |dump|
        next if kept_keys.include?(dump.key)
        next unless dump.last_modified < cutoff

        client.delete_object(bucket: bucket_name, key: dump.key)
      end
    end

    def list_objects(prefix)
      objects = []
      continuation_token = nil

      loop do
        params = { bucket: bucket_name, prefix: }
        params[:continuation_token] = continuation_token if continuation_token
        response = client.list_objects_v2(**params)
        objects.concat(response.contents)
        break unless response.is_truncated

        continuation_token = response.next_continuation_token
      end

      objects
    end

    def client
      @client ||= @client_builder.call(
        endpoint: env.fetch("BACKUP_BUCKET_ENDPOINT"),
        region: env.fetch("BACKUP_BUCKET_REGION"),
        credentials: Aws::Credentials.new(
          env.fetch("BACKUP_BUCKET_ACCESS_KEY_ID"),
          env.fetch("BACKUP_BUCKET_SECRET_ACCESS_KEY")
        ),
        force_path_style: false,
        # Some S3-compatible stores reject newer SDK checksum defaults; these options limit checksums to required requests.
        request_checksum_calculation: "when_required",
        response_checksum_validation: "when_required"
      )
    end

    def bucket_name
      env.fetch("BACKUP_BUCKET_NAME")
    end

    def with_database_dump
      tempfile = Tempfile.new([ "flockwork-database", ".dump" ])
      tempfile.binmode
      stderr, status = dump_runner.call(pg_environment, [ "pg_dump", "--format=custom" ], tempfile)
      tempfile.flush
      raise DumpError, "pg_dump failed: #{stderr.strip}" unless status.success?

      tempfile.rewind
      yield tempfile
    ensure
      tempfile&.close!
    end

    def pg_environment
      config = connection_config.symbolize_keys
      {
        "PGHOST" => config[:host].to_s,
        "PGPORT" => config[:port].to_s,
        "PGUSER" => config[:username].to_s,
        "PGPASSWORD" => config[:password].to_s,
        "PGDATABASE" => config[:database].to_s
      }
    end

    def connection_config
      @connection_config ||= ActiveRecord::Base.connection_db_config.configuration_hash
    end

    def run_pg_dump(pg_env, argv, tempfile)
      stderr_output = nil
      status = nil

      Open3.popen3(pg_env, *argv) do |stdin, stdout, stderr, wait_thread|
        stdin.close
        stderr_reader = Thread.new { stderr.read }
        IO.copy_stream(stdout, tempfile)
        stderr_output = stderr_reader.value
        status = wait_thread.value
      end

      [ stderr_output, status ]
    end
end
