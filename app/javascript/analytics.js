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

// Signing in or out swaps the page through Turbo without reloading this module.
// Demo visitors have no posthog-person tag and keep their anonymous id, which the server reuses.
function syncIdentity() {
  const current = meta("posthog-person")
  if (current && current !== posthog.get_distinct_id()) {
    posthog.identify(current)
  } else if (!current && posthog.get_distinct_id()?.startsWith("person_")) {
    posthog.reset()
  }

  const organization = meta("posthog-organization")
  if (organization && organization !== posthog.getGroups().organization) posthog.group("organization", organization)
}

syncIdentity()
document.addEventListener("turbo:load", syncIdentity)
