# Be sure to restart your server when you modify this file.

# Scripts are strict ('self' + per-request nonce). Styles keep 'unsafe-inline' because
# views and Trix use inline style attributes; tighten once those are moved to classes.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.object_src  :none
    # 'wasm-unsafe-eval' lets pdf.js instantiate its JPEG2000/JBIG2 decoders; it does not allow eval().
    policy.script_src  :self, :wasm_unsafe_eval, "https://us-assets.i.posthog.com"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, :blob
    policy.media_src   :self, :data, :blob
    # Action Cable is same-origin; wss://api.x.ai is the voice planner realtime socket; PostHog is product analytics.
    policy.connect_src :self, "wss://api.x.ai", "https://us.i.posthog.com", "https://us-assets.i.posthog.com"
  end

  # No session on public pages, so the nonce is random per request.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
