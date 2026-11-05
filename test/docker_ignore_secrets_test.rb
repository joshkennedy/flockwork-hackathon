require "test_helper"
require "open3"
require "rubygems/package"
require "tmpdir"

class DockerIgnoreSecretsTest < ActiveSupport::TestCase
  REQUIRED_PATTERNS = [
    "/.claude/",
    "**/.env*",
    "**/config/credentials/*.key"
  ].freeze

  SECRET_PATHS = [
    ".claude/worktrees/spike/.env.development.local",
    ".claude/worktrees/spike/config/credentials/development.key",
    "vendor/plugin/.env.production",
    "lib/nested/config/credentials/staging.key"
  ].freeze

  test ".dockerignore excludes /.claude/, **/.env*, and **/config/credentials/*.key" do
    contents = File.read(Rails.root.join(".dockerignore"))

    REQUIRED_PATTERNS.each do |pattern|
      assert_includes contents, pattern
    end
  end

  test ".gitignore excludes /.claude/worktrees/, **/.env*, and **/config/credentials/*.key" do
    contents = File.read(Rails.root.join(".gitignore"))

    [
      "/.claude/worktrees/",
      "**/.env*",
      "**/config/credentials/*.key"
    ].each do |pattern|
      assert_includes contents, pattern
    end
  end

  test "docker build context listing omits nested env files, credential keys, and .claude" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".dockerignore"), File.read(Rails.root.join(".dockerignore")))
      File.write(File.join(dir, "Dockerfile"), "FROM scratch\nCOPY . /app\n")
      File.write(File.join(dir, "keep.txt"), "ok\n")

      SECRET_PATHS.each do |path|
        full = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, "secret\n")
      end

      listing = docker_context_listing(dir)

      assert listing.any? { |entry| entry.end_with?("keep.txt") },
        "expected keep.txt in the docker context, got:\n#{listing.join("\n")}"

      SECRET_PATHS.each do |path|
        leaked = listing.select { |entry| entry.include?(path) }
        assert_empty leaked, "expected #{path} to be absent from docker context, got:\n#{listing.join("\n")}"
      end
    end
  end

  private
    def docker_context_listing(dir)
      tar_data, err, status = Open3.capture3(
        { "DOCKER_BUILDKIT" => "1" },
        "docker", "build",
        "--progress=quiet",
        "--output", "type=tar,dest=-",
        "-f", "Dockerfile",
        ".",
        chdir: dir
      )
      assert status.success?, err

      listing = []
      Gem::Package::TarReader.new(StringIO.new(tar_data)).each do |entry|
        listing << entry.full_name
      end
      listing
    end
end
