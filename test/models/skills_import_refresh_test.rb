require "test_helper"

class SkillsImportRefreshTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper

  test "CSV normalizes optional skills and leaves existing skills when column is absent" do
    person = people(:leader)
    person.update!(skills: [ "music" ])
    organization = person.organization
    CsvImport.new(organization, "name,email\nLeo,#{person.email}\n").call
    assert_equal [ "music" ], person.reload.skills

    CsvImport.new(organization, "name,email,skills\nLeo,#{person.email},\" Cooking, driving, COOKING \"\n").call
    assert_equal [ "cooking", "driving" ], person.reload.skills

    CsvImport.new(organization, "name,email,skills\nNew Helper,new-helper@example.test,teaching\n").call
    assert_equal [ "teaching" ], organization.people.find_by!(email: "new-helper@example.test").skills
  end

  test "skill changes refresh affected active Projects only with no directory data" do
    project = projects(:building_cleanup)
    project.update!(skills_needed: [ "music" ])
    other = projects(:community_meal)
    other.update!(skills_needed: [ "driving" ])
    person = people(:other_volunteer)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ project ])
    other_stream = Turbo::StreamsChannel.send(:stream_name_from, [ other ])

    assert_no_broadcasts other_stream do
      messages = capture_broadcasts(stream) { perform_enqueued_jobs { person.update!(skills: [ "music" ]) } }
      assert_equal 1, messages.size
      assert_includes messages.first, 'action="refresh"'
      assert_not_includes messages.first, person.name
    end
    assert_broadcasts(stream, 1) { perform_enqueued_jobs { person.update!(skills: []) } }
    assert_no_broadcasts(stream) { perform_enqueued_jobs { person.update!(name: "New helper name") } }
    project.update!(archived_at: Time.current)
    assert_no_broadcasts(stream) { perform_enqueued_jobs { person.update!(skills: [ "music" ]) } }
  end

  test "skill changes enqueue the refresh instead of broadcasting inside the save" do
    project = projects(:building_cleanup)
    project.update!(skills_needed: [ "music" ])
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ project ])

    assert_no_broadcasts(stream) do
      assert_enqueued_jobs(1) { people(:other_volunteer).update!(skills: [ "music" ]) }
    end
  end
end
