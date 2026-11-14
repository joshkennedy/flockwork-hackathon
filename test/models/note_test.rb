require "test_helper"

class NoteTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper

  test "Project Note changes refresh open Project pages" do
    project = projects(:community_meal)
    stream = Turbo::StreamsChannel.send(:stream_name_from, project)

    assert_broadcasts(stream, 1) do
      perform_enqueued_jobs do
        project.notes.create!(
          organization: project.organization,
          author: people(:leader),
          visibility: :team,
          body: "Dinner setup moved to four."
        )
      end
    end
  end
end
