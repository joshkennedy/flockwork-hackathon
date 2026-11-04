require "application_system_test_case"

class CommentMorphTest < ApplicationSystemTestCase
  test "refresh preserves a comment draft and posting clears only the submitted form" do
    project = Project.create_for(creator: people(:grace_leader), attributes: { name: "Comment refresh", enabled_tools: [ "tasks" ] })
    first = project.tasks.create!(title: "First task")
    second = project.tasks.create!(title: "Second task")
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(project)

    [ first, second ].each do |task|
      within("details[data-commentable-type='Task'][data-commentable-id='#{task.id}']") do
        find("summary").click
        find("trix-editor").click
        find("trix-editor").send_keys("Draft for #{task.title}")
      end
    end

    project.update!(name: "Refreshed project")
    page.execute_script("Turbo.session.refresh(window.location.href)")
    assert_selector "h1", text: "Refreshed project"
    [ first, second ].each do |task|
      assert_selector "details[open][data-commentable-id='#{task.id}'] trix-editor", text: "Draft for #{task.title}"
    end

    within("details[data-commentable-type='Task'][data-commentable-id='#{first.id}']") do
      click_on "Post Comment"
      assert_selector "ol", text: "Draft for First task"
      assert_selector "trix-editor", text: "", exact_text: true
    end
    assert_selector "details[open][data-commentable-id='#{second.id}'] trix-editor", text: "Draft for Second task"
    assert_equal "Draft for First task", first.comments.last.body.to_plain_text.strip
  end

  test "an open Slot comment panel survives a refresh with its draft" do
    project = Project.create_for(creator: people(:grace_leader), attributes: { name: "Slot comment refresh", enabled_tools: [ "signup_sheet" ] })
    slot = project.slots.create!(label: "Welcome team", date: Date.current)
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(project)
    find("summary[aria-label='Actions for Welcome team on #{Date.current.strftime('%B %-d')}']").click
    click_on "Add Comment"
    panel = "section[data-commentable-type='Slot'][data-commentable-id='#{slot.id}']"
    within(panel) { find("trix-editor").send_keys("Keep the welcome draft") }
    project.update!(name: "Slot refreshed")
    page.execute_script("Turbo.session.refresh(window.location.href)")
    assert_selector "h1", text: "Slot refreshed"
    assert_selector "#{panel} trix-editor", text: "Keep the welcome draft"
    assert_selector "[data-comment-thread-target='trigger'][aria-expanded='true']", visible: :all
  end

  test "a rejected comment leaves its editor draft and displays the error" do
    project = Project.create_for(creator: people(:grace_leader), attributes: { name: "Rejected comment", enabled_tools: [ "tasks" ] })
    task = project.tasks.create!(title: "Draft task")
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(project)
    within("details[data-commentable-type='Task'][data-commentable-id='#{task.id}']") do
      find("summary").click
      find("trix-editor").send_keys("Keep this rejected draft")
      page.execute_script("const form = document.getElementById('comment_form_task_#{task.id}'); form.noValidate = true; form.addEventListener('formdata', (event) => event.formData.set('comment[body]', ''))")
      click_on "Post Comment"
      assert_selector "[role=alert]", text: "Body can't be blank"
      assert_selector "trix-editor", text: "Keep this rejected draft"
    end
    assert_equal 0, task.comments.count
  end
end
