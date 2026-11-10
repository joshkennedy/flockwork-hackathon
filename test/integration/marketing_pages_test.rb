require "test_helper"

class MarketingPagesTest < ActionDispatch::IntegrationTest
  test "registry routes reach the marketing controller" do
    assert_recognizes({ controller: "marketing_pages", action: "show", slug: "pricing" }, pricing_path)
    assert_recognizes({ controller: "marketing_pages", action: "show", slug: "features/sign-ups" }, features_sign_ups_path)
    assert_recognizes({ controller: "marketing_pages", action: "show", slug: "terms" }, terms_path)
  end

  test "an unknown feature is a 404" do
    get "/features/nope"
    assert_response :not_found
  end

  test "signed-in visitors read marketing pages in the public chrome" do
    sign_in_as_leader
    get terms_path
    assert_response :success
    assert_select ".public-header"
    assert_select ".lp-footer"
    assert_select "aside[aria-label=Organization]", count: 0
  end
end
