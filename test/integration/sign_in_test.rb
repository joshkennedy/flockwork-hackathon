require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  test "requesting a link emails the Person exactly once, and following it signs them in" do
    assert_emails 1 do
      perform_enqueued_jobs do
        post sign_in_requests_path, params: { email: "leo@st-example.test" }
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "leo@st-example.test" ], mail.to
    assert_equal "outbound", mail["MESSAGE-STREAM"].to_s

    token = mail.body.encoded[%r{/sign_in/(\S+)}, 1]
    get sign_in_link_path(token)
    assert_response :success
    post sign_in_link_path(token)

    assert_redirected_to home_path
    follow_redirect!
    assert_select "[data-signed-in-as]", "Leo Leader"
  end

  test "a link that was already used is refused with a plain message and starts no session" do
    token = request_sign_in_link(people(:leader))
    post sign_in_link_path(token)
    delete session_path

    post sign_in_link_path(token)

    assert_response :unprocessable_content
    assert_select "p", "That sign-in link has expired or was already used. Request a new one."
    get home_path
    assert_redirected_to root_path
  end

  test "a link older than 15 minutes is refused" do
    token = request_sign_in_link(people(:volunteer))

    travel 16.minutes do
      get sign_in_link_path(token)
      assert_response :unprocessable_content
      assert_select "p", "That sign-in link has expired or was already used. Request a new one."

      post sign_in_link_path(token)
      assert_response :unprocessable_content
    end

    get home_path
    assert_redirected_to root_path
  end

  test "a Person without an email cannot request a link, and the response reveals nothing" do
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path, params: { email: "" }
      end
    end
    assert_redirected_to check_email_path
    follow_redirect!
    assert_select "h1", "Check your email"
  end

  test "an unknown email gets the same response and no link is sent" do
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path, params: { email: "nobody@st-example.test" }
      end
    end
    assert_redirected_to check_email_path
    follow_redirect!
    assert_select "h1", "Check your email"
  end

  test "one email in two Organizations gets a single link, then chooses which organization to enter" do
    leo_elsewhere = organizations(:outsider_church).people.create!(name: "Leo Elsewhere", email: "leo@st-example.test")

    assert_emails 1 do
      token = request_sign_in_link(people(:leader))
      post sign_in_link_path(token)
    end

    assert_redirected_to new_organization_choice_path
    follow_redirect!
    assert_select "button", text: "St. Example"
    assert_select "button", text: "Outsider Church"

    post organization_choice_path, params: { person_id: leo_elsewhere.id }

    assert_redirected_to home_path
    follow_redirect!
    assert_select "[data-organization-name]", "Outsider Church"
    assert_select "[data-signed-in-as]", "Leo Elsewhere"
  end

  test "choosing an organization cannot switch to a Person with a different email" do
    sign_in_as_leader

    post organization_choice_path, params: { person_id: people(:outsider).id }

    assert_response :not_found
    get home_path
    assert_select "[data-signed-in-as]", "Leo Leader"
  end

  test "a Person in one Organization skips the chooser" do
    token = request_sign_in_link(people(:leader))

    post sign_in_link_path(token)

    assert_redirected_to home_path
  end

  test "sign out ends the session" do
    sign_in_as_leader

    delete session_path

    assert_redirected_to root_path
    get home_path
    assert_redirected_to root_path
  end
end
