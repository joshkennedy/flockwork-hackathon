import posthog from "posthog-js"

const meta = (name) => document.querySelector(`meta[name="${name}"]`)?.content

const person = meta("posthog-person")

posthog.init(meta("posthog-key"), {
  api_host: "https://us.i.posthog.com",
  person_profiles: "identified_only",
  // Turbo navigates with pushState, so each visit counts as a pageview.
  capture_pageview: "history_change",
  disable_session_recording: true,
  disable_surveys: true,
  bootstrap: person ? { distinctID: person, isIdentifiedID: true } : {}
})
if (person) posthog.group("organization", meta("posthog-organization"))

// Signing in or out swaps the page through Turbo without reloading this module.
document.addEventListener("turbo:load", () => {
  const current = meta("posthog-person")
  if (current && current !== posthog.get_distinct_id()) {
    posthog.identify(current)
    posthog.group("organization", meta("posthog-organization"))
  } else if (!current && posthog.get_distinct_id()?.startsWith("person_")) {
    posthog.reset()
  }
})
