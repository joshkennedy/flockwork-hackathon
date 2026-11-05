require "test_helper"

class EmailChangeConfirmationTest < ActionDispatch::IntegrationTest
  test "an Admin's email change waits for the new address to confirm and mails it a link" do
    sign_in_as_admin

    assert_emails 1 do
      perform_enqueued_jobs do
        patch person_path(people(:volunteer)), params: { person: { name: "Victor Volunteer", email: "New.Vic@st-example.test" } }
      end
    end

    assert_redirected_to person_path(people(:volunteer))
    people(:volunteer).reload
    assert_equal "vic@st-example.test", people(:volunteer).email
    assert_equal "new.vic@st-example.test", people(:volunteer).pending_email
    assert_equal [ "new.vic@st-example.test" ], ActionMailer::Base.deliveries.last.to

    follow_redirect!
    assert_select "p", /Pending: new\.vic@st-example\.test, waiting for confirmation/
  end

  test "the confirmation link applies the change once, signs nobody in, and the old email works until then" do
    sign_in_as_admin
    token = request_email_change(people(:volunteer), "new.vic@st-example.test")
    delete session_path

    assert_emails 1 do
      perform_enqueued_jobs { post sign_in_requests_path, params: { email: "vic@st-example.test" } }
    end
    assert_no_emails do
      perform_enqueued_jobs { post sign_in_requests_path, params: { email: "new.vic@st-example.test" } }
    end

    get email_confirmation_path(token)
    assert_response :success
    assert_equal "vic@st-example.test", people(:volunteer).reload.email

    post email_confirmation_path(token)
    assert_response :success
    assert_select "h1", "Email confirmed"
    get home_path
    assert_redirected_to "/"
    people(:volunteer).reload
    assert_equal "new.vic@st-example.test", people(:volunteer).email
    assert_nil people(:volunteer).pending_email

    post email_confirmation_path(token)
    assert_response :unprocessable_content
    assert_select "h1", "Confirmation link not valid"
  end

  test "an expired confirmation link changes nothing" do
    sign_in_as_admin
    token = request_email_change(people(:volunteer), "new.vic@st-example.test")

    travel 25.hours do
      post email_confirmation_path(token)
    end

    assert_response :unprocessable_content
    assert_equal "vic@st-example.test", people(:volunteer).reload.email
  end

  test "an address taken before confirmation is refused at confirm time" do
    sign_in_as_admin
    token = request_email_change(people(:volunteer), "new.vic@st-example.test")
    people(:leader).update!(email: "new.vic@st-example.test")

    post email_confirmation_path(token)

    assert_response :unprocessable_content
    assert_equal "vic@st-example.test", people(:volunteer).reload.email
  end

  test "a newer request replaces the older pending address and voids its link" do
    sign_in_as_admin
    old_token = request_email_change(people(:volunteer), "first@st-example.test")
    request_email_change(people(:volunteer), "second@st-example.test")

    post email_confirmation_path(old_token)

    assert_response :unprocessable_content
    assert_equal "vic@st-example.test", people(:volunteer).reload.email
    assert_equal "second@st-example.test", people(:volunteer).pending_email
  end

  test "a confirmed link stays dead after the address changes away and is requested again" do
    sign_in_as_admin
    first_a = request_email_change(people(:volunteer), "a@st-example.test")
    post email_confirmation_path(first_a)
    request_email_change(people(:volunteer), "b@st-example.test")
    post email_confirmation_path(ActionMailer::Base.deliveries.last.text_part.body.decoded[%r{/email_confirmations/(\S+)}, 1])
    request_email_change(people(:volunteer), "a@st-example.test")

    post email_confirmation_path(first_a)

    assert_response :unprocessable_content
    assert_equal "b@st-example.test", people(:volunteer).reload.email
    assert_equal "a@st-example.test", people(:volunteer).pending_email
  end

  test "a link for a pending address the Admin cleared is rejected and the email stays blank" do
    sign_in_as_admin
    person = organizations(:st_example).people.create!(name: "No Email", email: nil)
    token = request_email_change(person, "ne@st-example.test")
    patch person_path(person), params: { person: { name: "No Email", email: "" } }

    post email_confirmation_path(token)

    assert_response :unprocessable_content
    assert_nil person.reload.email
    assert_nil person.pending_email
  end

  test "saving a blank email on a Person with no email clears a pending address" do
    sign_in_as_admin
    person = organizations(:st_example).people.create!(name: "No Email", email: nil, pending_email: "ne@st-example.test")

    patch person_path(person), params: { person: { name: "No Email", email: "" } }

    assert_nil person.reload.pending_email
  end

  test "setting an email where none existed is pending too" do
    sign_in_as_admin
    person = organizations(:st_example).people.create!(name: "No Email", email: nil)

    patch person_path(person), params: { person: { name: "No Email", email: "ne@st-example.test" } }

    assert_nil person.reload.email
    assert_equal "ne@st-example.test", person.pending_email
  end

  test "an address already used in the Organization is rejected up front" do
    sign_in_as_admin

    assert_no_emails do
      patch person_path(people(:volunteer)), params: { person: { name: "Victor", email: people(:leader).email } }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Email has already been taken/
    assert_nil people(:volunteer).reload.pending_email
  end

  test "saving the form with the unchanged email sends nothing and keeps a pending change" do
    sign_in_as_admin
    request_email_change(people(:volunteer), "new.vic@st-example.test")

    assert_no_emails do
      patch person_path(people(:volunteer)), params: { person: { name: "Vic V", email: "vic@st-example.test" } }
    end

    people(:volunteer).reload
    assert_equal "Vic V", people(:volunteer).name
    assert_equal "new.vic@st-example.test", people(:volunteer).pending_email
  end

  test "clearing the email removes it and any pending change right away" do
    sign_in_as_admin
    request_email_change(people(:volunteer), "new.vic@st-example.test")

    patch person_path(people(:volunteer)), params: { person: { name: "Vic", email: "" } }

    people(:volunteer).reload
    assert_nil people(:volunteer).email
    assert_nil people(:volunteer).pending_email
  end

  private
    def request_email_change(person, address)
      perform_enqueued_jobs do
        patch person_path(person), params: { person: { name: person.name, email: address } }
      end
      ActionMailer::Base.deliveries.last.text_part.body.decoded[%r{/email_confirmations/(\S+)}, 1]
    end
end
