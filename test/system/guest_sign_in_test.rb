require "application_system_test_case"

class GuestSignInTest < ApplicationSystemTestCase
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
    page.current_window.resize_to(390, 844)
    visit public_project_path(@project.public_token)
    click_on "Help with This"

    fill_in "Email or mobile number", with: "nadia@example.com"
    click_on "Send Me a Code"

    assert_selector "h1", text: "Enter your code"
    fill_in "6-digit code", with: ActionMailer::Base.deliveries.last.subject[/\A\d{6}/]
    click_on "Continue"

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
    assert_equal [ "Nadia Novak" ], @project.slots.last.people.map(&:name)
  end
end
