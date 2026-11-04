require "test_helper"

class ProjectDigestMailerTest < ActionMailer::TestCase
  test "weekly summary uses Project risk counts and dates" do
    project = projects(:community_meal)
    project.update!(enabled_tools: %w[tasks signup_sheet])
    project.slots.create!(label: "Setup", date: Date.current + 2, capacity: 3)
    project.tasks.create!(title: "Bring plates", due_on: Date.yesterday)
    project.invitations.create!(organization: project.organization, person: people(:other_volunteer), inviter: people(:leader), role: :volunteer)

    email = ProjectDigestMailer.weekly(project, people(:leader))

    assert_equal [ people(:leader).email ], email.to
    assert_includes email.text_part.body.to_s, "3 open spots in the next 7 days."
    assert_includes email.text_part.body.to_s, "1 overdue task."
    assert_includes email.text_part.body.to_s, "1 unanswered invitation."
    assert_includes email.text_part.body.to_s, project.starts_on.strftime("%B %-d, %Y")
    assert_includes email.text_part.body.to_s, "/projects/#{project.id}"
    assert_includes email.text_part.body.to_s, "/digest_preferences"
    assert_includes email.html_part.body.to_s, "/digest_preferences"
    assert_includes email.html_part.body.to_s, "Manage weekly emails"
  end

  test "volunteers and Leaders who opted out receive no digest" do
    project = projects(:community_meal)
    assert_nil ProjectDigestMailer.weekly(project, people(:volunteer)).message.to
    person = people(:leader)
    person.update!(email_preferences: { "weekly_project_digest" => false })
    assert_nil ProjectDigestMailer.weekly(project, person).message.to
  end
end
