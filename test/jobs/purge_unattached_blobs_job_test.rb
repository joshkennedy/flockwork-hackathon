require "test_helper"
require "yaml"

class PurgeUnattachedBlobsJobTest < ActiveJob::TestCase
  test "purges only unattached blobs older than two days" do
    old_unattached = create_blob("old-unattached.txt", created_at: 3.days.ago)
    recent_unattached = create_blob("recent-unattached.txt", created_at: 1.day.ago)
    old_attached = create_blob("old-attached.txt", created_at: 3.days.ago)
    attach_to_doc_item(old_attached)

    PurgeUnattachedBlobsJob.perform_now

    assert_not ActiveStorage::Blob.exists?(old_unattached.id)
    assert ActiveStorage::Blob.exists?(recent_unattached.id)
    assert ActiveStorage::Blob.exists?(old_attached.id)
  end

  test "runs every day in production" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    schedule = recurring.dig("production", "purge_unattached_blobs")

    assert_equal "PurgeUnattachedBlobsJob", schedule.fetch("class")
    assert_equal "at 2am every day", schedule.fetch("schedule")
  end

  private
    def create_blob(filename, created_at:)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("Flockwork test upload\n"),
        filename:,
        content_type: "text/plain"
      ).tap { |blob| blob.update_column(:created_at, created_at) }
    end

    def attach_to_doc_item(blob)
      session = people(:leader).sessions.create!(user_agent: "Test", ip_address: "127.0.0.1")
      Current.set(session:) do
        project = Current.organization.projects.find_by!(name: "Community Meal")
        item = project.doc_items.build(kind: :file, title: "Kept file", author: Current.person)
        item.file.attach(blob)
        item.save!
      end
    end
end
