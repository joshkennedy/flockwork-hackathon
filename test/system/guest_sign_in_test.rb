require "application_system_test_case"

class GuestSignInSystemTest < ApplicationSystemTestCase
  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    @project = projects(:community_meal)
    @project.update!(enabled_tools: @project.enabled_tools | [ "signup_sheet" ])
    @project.enable_public_link!
    @project.slots.create!(date: Date.current + 3, label: "Dinner", capacity: 1)
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "a new helper goes from the Public link to a claimed Slot with an emailed code" do
    tapped = @project.slots.last
    # Rows below the tapped one and a Later group give the page room to scroll, on any weekday.
    5.times { |i| @project.slots.create!(date: tapped.date, starts_at_time: "#{i + 1}:00 PM", label: "Dinner", capacity: 1) }
    later = 5.times.map { |i| @project.slots.create!(date: Date.current + 30 + i, label: "Dinner", capacity: 1) }.first
    page.current_window.resize_to(390, 844)
    visit public_project_path(@project.public_token)
    within("#slot_#{tapped.id}") { click_on "Help with This" }

    fill_in "Email or mobile number", with: "nadia@example.com"
    click_on "Send Me a Code"

    assert_selector "h1", text: "Enter your code"
    code = ActionMailer::Base.deliveries.last.subject[/\A\d{6}/]
    fill_in "6-digit code", with: code == "000000" ? "111111" : "000000"
    click_on "Verify Code"

    assert_selector "[role=alert]", text: "That code didn’t match."
    field = find_field("6-digit code")
    assert_equal [ 0, 6 ], page.evaluate_script("[document.activeElement.selectionStart, document.activeElement.selectionEnd]"), "the wrong digits are selected"
    field.send_keys code
    assert_equal code, field.value, "typing replaces the selected digits"
    click_on "Verify Code"

    fill_in "First and last name", with: "Nadia Novak"
    click_on "Confirm My Spot"

    assert_selector "li[id^=slot_]:focus", text: "You’re bringing dinner"
    assert_match(/#slot_\d+\z/, page.current_url)
    assert_no_selector ".tst"
    overlaps = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".tst")].flatMap((toast) => {
        const t = toast.getBoundingClientRect()
        return [...document.querySelectorAll("main header > *, #public-slots")]
          .filter((text) => { const r = text.getBoundingClientRect(); return t.left < r.right && r.left < t.right && t.top < r.bottom && r.top < t.bottom })
          .map((text) => text.textContent.trim())
      })
    JS
    assert_empty overlaps, "the claim's confirmation must not cover the page text"
    assert_equal [ "Nadia Novak" ], tapped.people.map(&:name)
    assert_landed_on tapped, below: "#public-slots"

    find("summary", text: "Later Slots").click unless page.has_css?("[data-signup-later][open]", wait: 0)
    within("#slot_#{later.id}") { click_on "I Can Bring Dinner" }
    assert_selector "#slot_#{later.id}:focus", text: "You’re bringing dinner"
    assert_landed_on later, below: "[data-signup-later] summary"
  end

  private
    # The heading or group label above a just-claimed row sits 24px from the top, and the whole row stays on screen.
    def assert_landed_on(slot, below:)
      anchor_top, row_bottom, height, at_bottom = page.evaluate_script(<<~JS)
        [document.querySelector(#{below.to_json}).getBoundingClientRect().top, document.getElementById("slot_#{slot.id}").getBoundingClientRect().bottom, innerHeight, scrollY + innerHeight >= document.documentElement.scrollHeight - 1]
      JS
      assert at_bottom || (anchor_top - 24).abs <= 1, "#{below} sits 24px from the top unless the page has run out of scroll (it sat at #{anchor_top})"
      assert_operator row_bottom, :<=, height, "the claimed row is fully in view"
      assert_selector "#slot_#{slot.id}:focus"
    end
end
