require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "landing page sends a nonce-based policy and blocks inline scripts without the nonce" do
    get root_path

    policy = response.headers["Content-Security-Policy"]
    nonce = policy[/script-src [^;]*'nonce-([^']+)'/, 1]
    assert nonce.present?
    assert_includes policy, "script-src 'self' 'wasm-unsafe-eval' 'nonce-#{nonce}'"
    assert_not_includes policy, "'unsafe-eval'"
    assert_not_includes policy[/script-src [^;]*/], "unsafe-inline"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "connect-src 'self' wss://api.x.ai"
    assert_select "script[nonce='#{nonce}']"
    assert_select "script[src*=device_theme]"
    assert_select "script:not([src]):not([type=importmap]):not([type=module])", false
    assert_select "script:not([nonce]):not([src])", false
  end

  test "signed in pages carry the policy and every inline script carries the nonce" do
    sign_in_as_admin
    get root_path
    follow_redirect! if response.redirect?

    nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    assert nonce.present?
    assert_select "script:not([nonce]):not([src])", false
    assert_select "[onclick]", false
  end
end
