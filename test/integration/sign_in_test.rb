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

  test "a removed Person cannot request or use a magic link" do
    person = people(:leader)
    token = person.generate_token_for(:sign_in)
    person.update!(removed_at: Time.current)

    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path, params: { email: person.email }
      end
    end
    assert_redirected_to check_email_path

    get sign_in_link_path(token)
    assert_response :unprocessable_content
    post sign_in_link_path(token)
    assert_response :unprocessable_content

    get home_path
    assert_redirected_to root_path
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
    assert_select "a", text: "Switch Church"
  end

  test "signing up with another Person's email cannot switch into that Person's Organization" do
    post organizations_path, params: {
      church_name: "Mallory Church",
      your_name: "Mallory",
      email: people(:leader).email
    }
    follow_redirect!

    assert_select "a", text: "Switch Church", count: 0

    post organization_choice_path, params: { person_id: people(:leader).id }
    get home_path

    assert_select "[data-signed-in-as]", "Mallory"
  end

  test "changing the signed-in Person's email does not transfer magic-link proof" do
    admin = people(:admin)
    outsider = people(:outsider)
    token = request_sign_in_link(admin)
    post sign_in_link_path(token)

    patch person_path(admin), params: { person: { email: outsider.email } }
    post organization_choice_path, params: { person_id: outsider.id }

    assert_response :not_found
    get home_path
    assert_select "[data-signed-in-as]", "Ada Admin"
  end

  test "changing a Person's email invalidates sign-in links sent to their old email" do
    outsider = people(:outsider)
    post organizations_path, params: {
      church_name: "Mallory Church",
      your_name: "Mallory",
      email: "mallory@example.test"
    }
    organization = Organization.find_by!(name: "Mallory Church")
    admin = organization.people.find_by!(email: "mallory@example.test")
    token = admin.generate_token_for(:sign_in)

    perform_enqueued_jobs do
      patch person_path(admin), params: { person: { email: outsider.email } }
    end
    assert_redirected_to person_path(admin)
    post email_confirmation_path(ActionMailer::Base.deliveries.last.text_part.body.decoded[%r{/email_confirmations/(\S+)}, 1])
    assert_equal "olive@outsider-church.test", admin.reload.email

    get sign_in_link_path(token)

    assert_response :unprocessable_content
    assert_select "p", "That sign-in link has expired or was already used. Request a new one."

    post organization_choice_path, params: { person_id: outsider.id }

    assert_response :not_found
    get home_path
    assert_select "[data-signed-in-as]", "Mallory"
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
