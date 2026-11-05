require "test_helper"

class MessagesTest < ActionDispatch::IntegrationTest
  test "a member cannot embed another church's blob" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("banner_small.png").open,
      filename: "banner.png",
      content_type: "image/png",
      metadata: { "organization_id" => organizations(:st_example).id }
    )
    sign_in_as_outsider
    project = projects(:outsider_project)
    project.update!(enabled_tools: project.enabled_tools + [ "messages" ])

    assert_no_difference [ "Message.count", "ActiveStorage::Attachment.count" ] do
      post project_messages_path(project), params: {
        message: { body: rich_text_with(blob, "Foreign image") }
      }
    end

    assert_redirected_to project_path(project)
    assert_match "belongs to another church", flash[:alert]
    assert_not project.messages.exists?
  end

  test "an unstamped legacy blob attached in another church cannot be embedded" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("banner_small.png").open,
      filename: "banner.png",
      content_type: "image/png"
    )
    projects(:community_meal).banner.attach(blob)
    sign_in_as_outsider
    project = projects(:outsider_project)
    project.update!(enabled_tools: project.enabled_tools + [ "messages" ])

    assert_no_difference [ "Message.count", "ActiveStorage::Attachment.count" ] do
      post project_messages_path(project), params: {
        message: { body: rich_text_with(blob, "Legacy foreign image") }
      }
    end

    assert_redirected_to project_path(project)
    assert_match "belongs to another church", flash[:alert]
    assert_not project.messages.exists?
  end

  test "a Team member posts messages and replies with expected order on the board" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    travel_to Time.zone.parse("2027-02-01 10:00") do
      post project_messages_path(project), params: { message: { body: "<div>First root</div>" } }
    end

    assert_redirected_to project_path(project)

    travel_to Time.zone.parse("2027-02-01 11:00") do
      post project_messages_path(project), params: { message: { body: "<div>Second root</div>" } }
    end

    first_root = project.messages.roots.order(:created_at).first!

    travel_to Time.zone.parse("2027-02-01 10:30") do
      post project_messages_path(project), params: {
        message: { parent_id: first_root.id, body: "<div>Early reply</div>" }
      }
    end

    travel_to Time.zone.parse("2027-02-01 10:45") do
      post project_messages_path(project), params: {
        message: { parent_id: first_root.id, body: "<div>Late reply</div>" }
      }
    end

    get project_path(project)

    assert_response :success
    assert_match "Second root", response.body
    assert_match "First root", response.body
    assert_match "Early reply", response.body
    assert_match "Late reply", response.body

    assert_select "section[aria-labelledby='tool-messages']" do
      assert_select ".message-composer textarea[name='message[body]'][placeholder='Write a Message']"
      assert_select "trix-editor", count: 0
      assert_select ".message-thread"
      bodies = css_select("[data-message-body]").map { |node| node.text.squish }
      assert_equal [
        "Second root",
        "First root",
        "Early reply",
        "Late reply"
      ], bodies
    end
  end

  test "the author edits their own message" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    post project_messages_path(project), params: { message: { body: "<div>Original text</div>" } }

    message = project.messages.roots.last!

    patch project_message_path(project, message), params: {
      message: { body: "<div>Updated text</div>" }
    }

    assert_redirected_to project_path(project)
    follow_redirect!

    assert_match "Updated text", response.body
    assert_no_match "Original text", response.body
  end

  test "another Team member cannot edit someone else's message" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    post project_messages_path(project), params: { message: { body: "<div>Volunteer post</div>" } }

    message = project.messages.roots.last!
    sign_in_as_leader

    get edit_project_message_path(project, message)

    assert_response :not_found

    patch project_message_path(project, message), params: {
      message: { body: "<div>Leader takeover</div>" }
    }

    assert_response :not_found
    assert_match "Volunteer post", message.reload.body.to_plain_text
  end

  test "a Leader deletes another Team member's message" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    post project_messages_path(project), params: { message: { body: "<div>Please remove me</div>" } }

    message = project.messages.roots.last!
    sign_in_as_leader

    assert_difference "Message.count", -1 do
      delete project_message_path(project, message)
    end

    assert_redirected_to project_path(project)
    follow_redirect!
    assert_no_match "Please remove me", response.body
  end

  test "a non-member cannot read or post messages" do
    sign_in_as_outsider
    project = projects(:community_meal)

    get project_path(project)

    assert_response :not_found

    post project_messages_path(project), params: { message: { body: "<div>Intruder</div>" } }

    assert_response :not_found
    assert_equal 0, project.messages.count
  end

  private
    def rich_text_with(blob, text)
      %(<div>#{text}</div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
    end
end
