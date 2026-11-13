require "test_helper"

class GuestSignInConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  SENDLY = "https://sendly.live/api/v1/messages".freeze

  setup do
    @project = projects(:community_meal)
    @saved = @project.slice(:enabled_tools, :public_token)
    @project.update!(enabled_tools: @project.enabled_tools | [ "signup_sheet" ])
    @project.enable_public_link!
    @token = @project.public_token

    @previous_key = ENV["SENDLY_API_KEY"]
    ENV["SENDLY_API_KEY"] = "sandbox"
    stub_request(:post, SENDLY).to_return(status: 201, body: { id: "msg_test", status: "queued" }.to_json)
  end

  teardown do
    @previous_key.nil? ? ENV.delete("SENDLY_API_KEY") : ENV["SENDLY_API_KEY"] = @previous_key
    people = Person.where(phone: "+12025550177")
    Session.where(person: people).delete_all
    people.delete_all
    SignInChallenge.delete_all
    @project.update_columns(@saved)
  end

  test "sending the name step twice at once makes one Person" do
    browser = open_session
    verify_phone(browser)
    browsers = 2.times.map { open_session.tap { |copy| browser.cookies.to_hash.each { |name, value| copy.cookies[name] = value } } }

    send_names_at_once(browsers)

    assert_equal 1, Person.where(phone: "+12025550177").count
    assert_equal 1, browsers.count { |each| each.response.redirect_url == public_project_url(@token) }
  end

  test "two browsers that each proved the same phone make one Person when they send their names at once" do
    browsers = 2.times.map { open_session.tap { |browser| verify_phone(browser) } }

    send_names_at_once(browsers)

    assert_equal 1, Person.where(phone: "+12025550177").count
  end

  private
    def verify_phone(browser)
      perform_enqueued_jobs { browser.post guest_sign_in_path(@token), params: { contact: "202-555-0177" } }
      code = nil
      assert_requested(:post, SENDLY, at_least_times: 1) { |request| code = JSON.parse(request.body)["text"][/\b\d{6}\b/] }
      browser.post guest_sign_in_code_path(@token), params: { code: }
      assert_equal guest_sign_in_name_url(@token), browser.response.redirect_url
    end

    # Holds each new Person at the insert until the other request gets there too, or a second passes, so both
    # requests are in flight at once instead of one finishing before the other starts.
    def send_names_at_once(browsers)
      both_creating = Concurrent::CountDownLatch.new(2)
      barrier = ->(_) { both_creating.count_down; both_creating.wait(1) }
      Person.set_callback(:create, :before, barrier)
      browsers.map { |browser| Thread.new { browser.post guest_sign_in_name_path(@token), params: { name: "Tom Text" } } }.each(&:join)
    ensure
      Person.skip_callback(:create, :before, barrier)
    end
end
