require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  test "requesting a link emails the Person exactly once, and following it signs them in" do
    assert_emails 1 do
      perform_enqueued_jobs do
        post sign_in_requests_path(workspaces(:st_example)), params: { email: "leo@st-example.test" }
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "leo@st-example.test" ], mail.to
    assert_equal "outbound", mail["MESSAGE-STREAM"].to_s

    token = mail.body.encoded[%r{/sign_in/(\S+)}, 1]
    get sign_in_link_path(token)
    assert_response :success
    post sign_in_link_path(token)

    assert_redirected_to "/st-example"
    follow_redirect!
    assert_select "p", "Signed in as Leo Leader"
  end

  test "a link that was already used is refused with a plain message and starts no session" do
    token = request_sign_in_link(people(:leader))
    post sign_in_link_path(token)
    delete session_path

    post sign_in_link_path(token)

    assert_response :unprocessable_content
    assert_select "p", "That sign-in link has expired or was already used. Request a new one."
    get workspace_path("st-example")
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

    get workspace_path("st-example")
    assert_redirected_to root_path
  end

  test "a Person without an email cannot request a link, and the response reveals nothing" do
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path(workspaces(:st_example)), params: { email: "" }
      end
    end
    assert_response :success
    assert_select "h1", "Check your email"
  end

  test "an unknown email gets the same response and no link is sent" do
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path(workspaces(:st_example)), params: { email: "nobody@st-example.test" }
      end
    end
    assert_response :success
    assert_select "h1", "Check your email"
  end

  test "a Person cannot request a link through another Workspace's sign-in page" do
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path(workspaces(:outsider_church)), params: { email: "ada@st-example.test" }
      end
    end
    assert_select "h1", "Check your email"
  end

  test "sign out ends the session" do
    sign_in_as_leader

    delete session_path

    assert_redirected_to root_path
    get workspace_path("st-example")
    assert_redirected_to root_path
  end
end
