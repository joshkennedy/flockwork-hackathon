require "test_helper"

class MessageThreadScopingTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @foreign_root = projects(:outsider_project).messages.create!(
      author: people(:outsider),
      body: "foreign root"
    )

    sign_in_as_volunteer
  end

  test "a Team member cannot reply to a message from another Project" do
    assert_no_difference -> { @project.messages.count } do
      post project_messages_path(@project), params: {
        message: { body: "foreign reply", parent_id: @foreign_root.id }
      }
    end

    assert_response :not_found
    assert_equal 0, @foreign_root.replies.count
  end

  test "a Team member cannot re-parent their message to another Project" do
    message = @project.messages.create!(author: people(:volunteer), body: "local root")

    patch project_message_path(@project, message), params: {
      message: { body: "updated root", parent_id: @foreign_root.id }
    }

    assert_redirected_to project_path(@project)
    assert_nil message.reload.parent_id
    assert_equal 0, @foreign_root.replies.count
  end

  test "a nonexistent reply parent returns not found" do
    post project_messages_path(@project), params: {
      message: { body: "missing reply", parent_id: Message.maximum(:id).to_i + 1 }
    }

    assert_response :not_found
  end
end
