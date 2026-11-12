require "test_helper"

class LegalPagesTest < ActionDispatch::IntegrationTest
  test "legal pages are public and describe the actual AI boundaries" do
    get terms_path
    assert_response :success
    assert_select "h1", "Terms."
    assert_select ".legal-updated", "Last updated November 9, 2026"
    get privacy_path
    assert_response :success
    assert_select "h1", "Privacy policy."
    assert_includes response.body, "OpenRouter"
    assert_includes response.body, "raw microphone audio directly to xAI"
    assert_includes response.body, "before Flockwork can redact them"
    assert_includes response.body, "browser’s speech recognition"
    assert_not_includes response.body, "PLACEHOLDER"
  end

  test "public discovery and the account menu link to legal pages" do
    get root_path
    [ terms_path, privacy_path ].each { |path| assert_select ".lp-footer a[href=?]", path }
    get "/sitemap.xml"
    [ terms_url, privacy_url ].each { |url| assert_includes response.body, "<loc>#{url}</loc>" }
    get "/llms.txt"
    [ terms_url, privacy_url ].each { |url| assert_includes response.body, url }
    sign_in_as_leader
    get home_path
    [ terms_path, privacy_path ].each { |path| assert_select ".account-menu a[href=?]", path, count: 1 }
    get privacy_path
    assert_response :success
    assert_select ".legal-page"
    assert_select ".public-header"
    assert_select ".auth-art", count: 0
  end
end
