require "test_helper"

class MailersTest < ActionMailer::TestCase
  test "the sign-in link email carries the link in both parts and says it expires" do
    person = people(:volunteer)
    mail = SignInMailer.sign_in_link(person)

    assert_equal [ person.email ], mail.to
    assert_equal "Your Flockwork sign-in link", mail.subject
    [ mail.html_part, mail.text_part ].each do |part|
      assert_match %r{http://example.com/sign_in/\S+}, part.body.decoded
      assert_match "expires in 15 minutes", part.body.decoded
    end
  end

  test "the welcome email names the Organization and explains signing in without a password" do
    admin = people(:admin)
    mail = WelcomeMailer.welcome(admin)

    assert_equal [ admin.email ], mail.to
    assert_equal "#{admin.organization.name} is set up on Flockwork", mail.subject
    [ mail.html_part, mail.text_part ].each do |part|
      assert_match "There's no password", part.body.decoded
      assert_match "http://example.com/home", part.body.decoded
    end
    assert_no_match %r{/sign_in/\S}, mail.body.encoded
  end

  test "the invitation email shows the Project, role and a link to answer it" do
    invitation = Invitation.create!(
      organization: organizations(:st_example),
      project: projects(:community_meal),
      person: people(:other_volunteer),
      inviter: people(:leader),
      role: "volunteer"
    )
    mail = InvitationMailer.invitation(invitation)

    assert_equal [ people(:other_volunteer).email ], mail.to
    html = mail.html_part.body.decoded
    assert_match projects(:community_meal).name, html
    assert_match "Volunteer", html
    assert_match "http://example.com/invitations/", html
  end

  test "a task assignment email shows the task, its due date and the preferences link" do
    task = projects(:community_meal).tasks.create!(title: "Bring folding tables", due_on: Date.new(2030, 3, 8), details: "Six of them.")
    mail = notification_email("task_assigned", task, actor: people(:leader))

    html = mail.html_part.body.decoded
    assert_equal "Leo Leader assigned you “Bring folding tables”.", mail.subject
    assert_match "Leo Leader assigned you a task", html
    assert_match "Friday, March 8, 2030", html
    assert_match "Six of them.", html
    assert_match "http://example.com/profile/edit", html
    assert_match "Due: Friday, March 8, 2030", mail.text_part.body.decoded
  end

  test "a slot reminder email shows when the Slot starts" do
    slot = projects(:community_meal).slots.create!(label: "Dinner", date: Date.tomorrow, starts_at_time: "18:00")
    mail = notification_email("slot_reminder", slot)

    assert_match "on for tomorrow", mail.html_part.body.decoded
    assert_match "at 6:00 PM", mail.html_part.body.decoded
    assert_match "When: #{slot.date.strftime("%A")}", mail.text_part.body.decoded
  end

  test "kinds without their own body fall back to the generic one" do
    mail = notification_email("team_departure", projects(:community_meal))

    assert_match "A Team member left #{projects(:community_meal).name}.", mail.html_part.body.decoded
    assert_match "http://example.com/projects/#{projects(:community_meal).id}", mail.text_part.body.decoded
  end

  private
    def notification_email(kind, notifiable, actor: nil)
      notification = people(:volunteer).notifications.create!(kind: kind, notifiable: notifiable, actor: actor)
      NotificationMailer.with(notification: notification).notification_email
    end
end
