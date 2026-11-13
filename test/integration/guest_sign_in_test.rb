require "test_helper"

class GuestSignInTest < ActionDispatch::IntegrationTest
  SENDLY = "https://sendly.live/api/v1/messages".freeze

  setup do
    @project = projects(:community_meal)
    @project.update!(enabled_tools: @project.enabled_tools | [ "signup_sheet" ])
    @project.enable_public_link!
    @token = @project.public_token
    @slot = @project.slots.create!(date: Date.current + 3, label: "Dinner", capacity: 1)
    # Vera is in the church but not on this Team, so nothing but the Public link lets her claim here.
    @vera = people(:other_volunteer)

    @previous_key = ENV["SENDLY_API_KEY"]
    ENV["SENDLY_API_KEY"] = "sandbox"
    @sms = stub_request(:post, SENDLY).to_return(status: 201, body: { id: "msg_test", status: "queued" }.to_json)
  end

  teardown do
    @previous_key.nil? ? ENV.delete("SENDLY_API_KEY") : ENV["SENDLY_API_KEY"] = @previous_key
  end

  test "the Public page sends helpers to its own sign-in, carrying the Slot they tapped" do
    get public_project_path(@token)

    assert_select "section[aria-labelledby='public-slots'] a.btn-secondary.btn-claim[href=?]", guest_sign_in_path(@token, slot_id: @slot.id), text: "Help with This"
    assert_select "a[href=?]", new_sign_in_request_path, count: 0
  end

  test "the need badge shows from two open spots up, signed in or out" do
    roomy = @project.slots.create!(date: Date.current + 4, label: "Dinner", capacity: 3)

    get public_project_path(@token)
    assert_select "#slot_#{@slot.id} .badge-need", count: 0
    assert_select "#slot_#{roomy.id} .badge-need", "3 spots left"

    sign_in_as @vera
    get public_project_path(@token)
    assert_select "#slot_#{@slot.id} .badge-need", count: 0
    assert_select "#slot_#{roomy.id} .badge-need", "3 spots left"
  end

  test "a signed-in helper sees who they are on the Public page, and Not You? signs out back to it" do
    get public_project_path(@token)
    assert_select "[data-public-account]", count: 0

    sign_in_as @vera
    get public_project_path(@token)
    assert_select "[data-public-account]", /Signed in as #{@vera.name}/
    assert_select "[data-public-account] form[action=?] button", guest_sign_out_path(@token), text: "Not You?"

    delete guest_sign_out_path(@token)
    assert_redirected_to public_project_path(@token)
    follow_redirect!
    assert_select "[data-public-account]", count: 0
    assert_select "a", text: "Help with This"
  end

  test "Tasks show on the Public page only to the Team, who can take one" do
    task = @project.tasks.create!(title: "Help with setup")

    get public_project_path(@token)
    assert_select "#public-tasks", count: 0
    assert_no_match "Help with setup", response.body

    sign_in_as @vera
    get public_project_path(@token)
    assert_select "#public-tasks", count: 0
    assert_no_match "Help with setup", response.body

    sign_in_as_volunteer
    get public_project_path(@token)
    assert_select "section[aria-labelledby='public-tasks'] form[action=?] button", claim_project_task_path(@project, task), text: "I’ll Do It"
  end

  test "someone already in the church signs in with an emailed code and holds the Slot they tapped" do
    get guest_sign_in_path(@token, slot_id: @slot.id)
    assert_select "h1", "Sign in to help"
    assert_select "input[type=hidden][name=slot_id][value=?]", @slot.id.to_s
    assert_select "[data-chosen-slot]", "#{@slot.date.strftime("%A, %B %-d")} · Dinner"

    code = request_code("Vera@St-Example.test ", slot: @slot)
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @vera.email ], mail.to
    follow_redirect!
    assert_select "h1", "Enter your code"
    assert_select "[data-chosen-slot]", "#{@slot.date.strftime("%A, %B %-d")} · Dinner"
    assert_select "p", /Sent to v•••@st-example.test/
    assert_select "input[name=code][autocomplete='one-time-code'][inputmode=numeric]"
    assert_select "form[action=?] input[name=slot_id][value=?]", guest_sign_in_path(@token), @slot.id.to_s
    assert_select "a[href=?]", guest_sign_in_path(@token, slot_id: @slot.id), text: "Use a different email or phone"

    assert_no_difference -> { Person.count } do
      post guest_sign_in_code_path(@token), params: { code: }
    end

    assert_redirected_to public_project_path(@token, anchor: "slot_#{@slot.id}")
    assert_equal [ @vera ], @slot.reload.people
    follow_redirect!
    assert_select "#flash [data-toast-kind=notice]", "You’re bringing dinner #{@slot.date.strftime("%A, %B %-d")}."
    assert_select "#slot_#{@slot.id}", /You’re signed up/
    assert_select "#slot_#{@slot.id}.tile-raised", count: 0
    assert_signed_in_as @vera
    assert_equal "email_code", @vera.sessions.last.auth_method
    assert_nil @vera.reload.joined_from_project
  end

  test "the one-tap link holds the tapped Slot even when opened in another browser" do
    request_code(@vera.email, slot: @slot)
    link = ActionMailer::Base.deliveries.last.text_part.body.encoded[%r{/go/(\S+)}, 1]

    open_session do |phone|
      phone.post guest_sign_in_link_path(link)
      phone.assert_redirected_to public_project_path(@token, anchor: "slot_#{@slot.id}")
    end
    assert_equal [ @vera ], @slot.reload.people
  end

  test "a new helper with a tapped Slot sees it on the name step and confirms the spot there" do
    code = request_code("nadia@example.com", slot: @slot)
    post guest_sign_in_code_path(@token), params: { code: }
    follow_redirect!
    assert_select "[data-chosen-slot]", "#{@slot.date.strftime("%A, %B %-d")} · Dinner"
    assert_select "input[type=submit][value=?]", "Confirm My Spot"

    post guest_sign_in_name_path(@token), params: { name: "Nadia Novak" }
    assert_redirected_to public_project_path(@token, anchor: "slot_#{@slot.id}")
    assert_equal [ "Nadia Novak" ], @slot.reload.people.map(&:name)
  end

  test "a Slot that filled up during sign-in is left alone, with a calm note" do
    code = request_code(@vera.email, slot: @slot)
    @slot.claim(people(:volunteer))

    post guest_sign_in_code_path(@token), params: { code: }
    assert_redirected_to public_project_path(@token, anchor: "slot_#{@slot.id}")
    assert_equal [ people(:volunteer) ], @slot.reload.people
    follow_redirect!
    assert_select "#flash [data-toast-kind=notice]", "That spot filled up while you were signing in. Pick another one below."
  end

  test "a slot_id from another Project is ignored" do
    other = projects(:community_meal).organization.projects.where.not(id: @project.id).first!
    foreign = other.slots.create!(date: Date.current + 3, label: "Dinner", capacity: 1)
    code = request_code(@vera.email, slot: foreign)

    post guest_sign_in_code_path(@token), params: { code: }
    assert_redirected_to public_project_path(@token)
    assert_empty foreign.reload.people
  end

  test "someone already in the church signs in with a texted code, however their phone was typed in" do
    @vera.update!(phone: "(202) 555-0123")
    get guest_sign_in_path(@token)
    assert_select "input[name=contact][aria-describedby=?]", "contact-texts"
    assert_select "#contact-texts", "Msg & data rates may apply. Reply STOP to opt out."

    code = request_code("(202) 555-0123")

    assert_requested @sms, times: 1
    assert_equal "+12025550123", last_sms.fetch("to")
    assert_operator last_sms.fetch("text").length, :<=, 160
    assert_match "is your code to help with Community Meal. Or tap: http://example.com/go/", last_sms.fetch("text")
    follow_redirect!
    assert_select "p", /Sent to \+1 ••• ••• 0123/

    assert_no_difference -> { Person.count } do
      post guest_sign_in_code_path(@token), params: { code: }
    end

    assert_signed_in_as @vera
    assert_equal "sms_code", @vera.sessions.last.auth_method
  end

  test "a shared phone signs in the Person with the least access" do
    people(:admin).update!(phone: "+12025550123")
    @vera.update!(phone: "1-202-555-0123")
    people(:outsider).update!(phone: "2025550123")

    post guest_sign_in_code_path(@token), params: { code: request_code("+12025550123") }

    assert_signed_in_as @vera
  end

  test "an Admin's phone gets no text and is asked for email, which still signs the Admin in" do
    admin = people(:admin)
    admin.update!(phone: "(202) 555-0123")

    assert_no_difference -> { SignInChallenge.count } do
      request_code("202-555-0123")
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Use your email to sign in."
    assert_not_requested @sms

    post guest_sign_in_code_path(@token), params: { code: request_code(admin.email) }
    assert_signed_in_as admin
  end

  test "a texted code does not sign in an Admin who took over the phone after it was sent" do
    people(:admin).update!(phone: "+12025550123")
    @vera.update!(phone: "+12025550123")
    code = request_code("+12025550123")
    @vera.update!(phone: nil)

    post guest_sign_in_code_path(@token), params: { code: }

    assert_select "[role=alert]", "Use your email to sign in."
    get home_path
    assert_redirected_to root_path
  end

  test "a new helper gives a name after the code, joins this church only, and can claim a Slot" do
    code = request_code("nadia@example.com")
    post guest_sign_in_code_path(@token), params: { code: }
    assert_redirected_to guest_sign_in_name_path(@token)
    follow_redirect!
    assert_select "h1", "What’s your name?"
    assert_select "[data-chosen-slot]", count: 0
    assert_select "input[type=submit][value=?]", "Continue"

    post guest_sign_in_name_path(@token), params: { name: "" }
    assert_response :unprocessable_content

    assert_difference -> { Person.count }, 1 do
      post guest_sign_in_name_path(@token), params: { name: " Nadia  Novak " }
    end
    nadia = Person.find_by!(email: "nadia@example.com")
    assert_equal "Nadia Novak", nadia.name
    assert_equal organizations(:st_example), nadia.organization
    assert_equal @project, nadia.joined_from_project
    assert_not nadia.admin?
    assert_redirected_to public_project_path(@token)
    follow_redirect!
    assert_select "form[action=?] button", public_slot_claim_path(@token, @slot), text: "I Can Bring Dinner"

    post public_slot_claim_path(@token, @slot)
    assert_redirected_to public_project_path(@token, anchor: "slot_#{@slot.id}")
    assert_equal [ nadia ], @slot.reload.people
    follow_redirect!
    assert_select "#slot_#{@slot.id}", /You’re signed up/

    # The Public link opens that page only: the Team's Project page stays closed, and Home and reminders lead back here.
    get home_path
    assert_select "a[href=?]", project_path(@project), text: /Dinner/
    get team_project_path(@project)
    assert_response :not_found
    get project_path(@project)
    assert_redirected_to public_project_path(@token)

    delete public_slot_claim_path(@token, @slot)
    assert_empty @slot.reload.people

    sign_in_as_admin
    get person_path(nadia)
    assert_select ".status-chip", "Joined from a public link"
  end

  test "a new helper can join by text with only a phone" do
    post guest_sign_in_code_path(@token), params: { code: request_code("202-555-0177") }
    post guest_sign_in_name_path(@token), params: { name: "Tom Text" }

    tom = Person.find_by!(phone: "+12025550177")
    assert_nil tom.email
    assert_equal @project, tom.joined_from_project
    assert_signed_in_as tom
  end

  test "the form answers the same way for a known and an unknown address" do
    request_code(@vera.email)
    assert_redirected_to guest_sign_in_code_path(@token)

    request_code("stranger@example.com")
    assert_redirected_to guest_sign_in_code_path(@token)
  end

  test "the one-tap link waits for a button press, then works once" do
    request_code(@vera.email)
    link = ActionMailer::Base.deliveries.last.text_part.body.encoded[%r{/go/(\S+)}, 1]

    2.times do
      get guest_sign_in_link_path(link)
      assert_response :success
      assert_select "form[action=?] button", guest_sign_in_link_path(link), text: "Sign In"
    end
    get home_path
    assert_redirected_to root_path

    post guest_sign_in_link_path(link)
    assert_redirected_to public_project_path(@token)
    assert_signed_in_as @vera
    assert_equal "link", @vera.sessions.last.auth_method

    delete session_path
    post guest_sign_in_link_path(link)
    assert_response :unprocessable_content
    assert_select "h1", "Sign-in link not valid"
    get home_path
    assert_redirected_to root_path
  end

  test "five wrong codes end the challenge, even for the right code and the link" do
    code = request_code(@vera.email)
    link = ActionMailer::Base.deliveries.last.text_part.body.encoded[%r{/go/(\S+)}, 1]
    wrong = code == "000000" ? "111111" : "000000"

    4.times do
      post guest_sign_in_code_path(@token), params: { code: wrong }
      assert_response :unprocessable_content
      assert_select "[role=alert]", "That code isn’t right. Check it and try again."
    end
    post guest_sign_in_code_path(@token), params: { code: wrong }
    assert_select "[role=alert]", "That code has expired or was tried too many times. Send a new one."

    post guest_sign_in_code_path(@token), params: { code: }
    post guest_sign_in_link_path(link)
    assert_response :unprocessable_content
    get home_path
    assert_redirected_to root_path
  end

  test "a code older than 15 minutes is refused" do
    code = request_code(@vera.email)
    link = ActionMailer::Base.deliveries.last.text_part.body.encoded[%r{/go/(\S+)}, 1]

    travel 16.minutes do
      post guest_sign_in_code_path(@token), params: { code: }
      assert_response :unprocessable_content
      get guest_sign_in_link_path(link)
      assert_response :unprocessable_content
    end
    get home_path
    assert_redirected_to root_path
  end

  test "a used code does not work again" do
    code = request_code(@vera.email)
    post guest_sign_in_code_path(@token), params: { code: }
    delete session_path

    post guest_sign_in_code_path(@token), params: { code: }

    assert_redirected_to guest_sign_in_path(@token)
    get home_path
    assert_redirected_to root_path
  end

  test "asking for a new code ends the earlier one" do
    first = request_code(@vera.email)
    second = request_code(@vera.email)
    first_link = ActionMailer::Base.deliveries.first.text_part.body.encoded[%r{/go/(\S+)}, 1]

    post guest_sign_in_link_path(first_link)
    assert_response :unprocessable_content

    post guest_sign_in_code_path(@token), params: { code: second }
    assert_signed_in_as @vera
    assert_not_equal first, second unless first == second
  end

  test "only the browser that proved the address may name the new Person" do
    request_code("nadia@example.com")
    link = ActionMailer::Base.deliveries.last.text_part.body.encoded[%r{/go/(\S+)}, 1]

    open_session { |other| other.post guest_sign_in_link_path(link) }

    assert_no_difference -> { Person.count } do
      post guest_sign_in_name_path(@token), params: { name: "Not Nadia" }
    end
    assert_redirected_to guest_sign_in_path(@token)
  end

  test "a phone that sent STOP gets no text and a calm message" do
    SmsOptOut.opt_out!("+12025550123", at: Time.current)

    assert_no_difference -> { SignInChallenge.count } do
      request_code("+1 202 555 0123")
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", "This number opted out of Flockwork texts. Use your email, or reply START to an earlier text."
    assert_not_requested @sms
  end

  test "only North American numbers get a text" do
    [ "+44 20 7946 0958", "+1 123 555 0123" ].each do |phone|
      assert_no_difference -> { SignInChallenge.count } do
        request_code(phone)
      end
      assert_response :unprocessable_content
      assert_select "[role=alert]", "Use your email for now."
    end
    assert_not_requested @sms
  end

  test "a church gets a capped number of sign-in texts an hour, then email still works" do
    organization = @project.organization
    SignInChallenge::ORGANIZATION_HOURLY_TEXT_LIMIT.times do |i|
      SignInChallenge.create!(organization:, channel: "sms", address: "+1202555#{format("%04d", i)}", expires_at: 15.minutes.from_now)
    end

    request_code("202-555-0177")
    assert_response :unprocessable_content
    assert_select "[role=alert]", "Use your email for now."
    assert_not_requested @sms

    assert request_code("nadia@example.com")
  end

  test "an address gets five codes an hour, and text that is neither an email nor a phone gets none" do
    5.times { request_code("nadia@example.com") }

    assert_no_emails { request_code("nadia@example.com") }
    assert_response :too_many_requests
    assert_select "[role=alert]", "Too many codes sent. Wait an hour, then try again."

    assert_no_emails { request_code("call me maybe") }
    assert_response :unprocessable_content
    assert_select "[role=alert]", "Enter an email, or a mobile number with its area code."
  end

  test "someone signed in to another church cannot claim here, and a full Slot says so" do
    sign_in_as_outsider
    post public_slot_claim_path(@token, @slot)
    assert_response :not_found

    @slot.claim(people(:volunteer))
    sign_in_as @vera
    post public_slot_claim_path(@token, @slot)
    follow_redirect!
    assert_select "#flash [data-toast-kind=alert]", "This Slot is full. Pick another one."
  end

  test "turning the Public link off closes the sign-in and claiming" do
    sign_in_as @vera
    @project.disable_public_link!

    get guest_sign_in_path(@token)
    assert_response :not_found
    post public_slot_claim_path(@token, @slot)
    assert_response :not_found
  end

  private
    # Asks for a code the way the form does and reads it from the email or text that went out.
    def request_code(contact, slot: nil)
      perform_enqueued_jobs { post guest_sign_in_path(@token), params: { contact:, slot_id: slot&.id } }
      return last_sms&.fetch("text")&.[](/\b\d{6}\b/) unless contact.include?("@")

      ActionMailer::Base.deliveries.last&.subject&.[](/\A\d{6}/)
    end

    def last_sms
      @last_sms = nil
      assert_requested(:post, SENDLY, at_least_times: 0) { |request| @last_sms = JSON.parse(request.body) }
      @last_sms
    end

    def assert_signed_in_as(person)
      get home_path
      assert_select "[data-signed-in-as]", person.name
    end
end
