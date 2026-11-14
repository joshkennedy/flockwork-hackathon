require "application_system_test_case"

class CommentMentionTest < ApplicationSystemTestCase
  test "typing @ and a name mentions that Person as a pill" do
    project = Project.create_for(creator: people(:grace_leader), attributes: { name: "Mention picking", enabled_tools: [ "tasks" ] })
    project.memberships.create!(person: people(:grace_volunteer), role: :volunteer)
    task = project.tasks.create!(title: "Count the chairs")
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(project)

    within("details[data-commentable-type='Task'][data-commentable-id='#{task.id}']") do
      find("summary").click
      editor = find("trix-editor")
      editor.click
      editor.send_keys("Thanks @Sa")
      assert_selector "[role=option][aria-selected=true]", text: "Sam Chen"
      editor.send_keys(:enter, "for the help")
      assert_selector "trix-editor .person-pill", text: "Sam Chen"
      assert_no_text "person:"

      click_on "Post Comment"
      assert_selector "ol .person-pill", text: "Sam Chen"
    end

    comment = task.comments.last!
    assert_equal "Thanks @Sam Chen for the help", comment.body.to_plain_text.squish
    assert comment.mentions.exists?(person: people(:grace_volunteer))
  end
end
