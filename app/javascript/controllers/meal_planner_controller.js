import { Controller } from "@hotwired/stimulus"

// Turbo broadcasts deliver results. A busy render can miss its broadcast (the cable may not be subscribed yet),
// so two one-shot checks run while a busy marker is in the frame: one for a quick finish, one at the stall threshold.
// Target callbacks fire on child swaps too, which the frame's stale data attributes after an answer do not.
const QUICK_CHECK_MS = 4_000
const STALL_CHECK_MS = 90_000

export default class extends Controller {
  static targets = ["status", "busy"]
  static values = { url: String }

  // Swapped-in live regions are rarely announced, so copy status text into the stable one.
  statusTargetConnected(element) {
    const announcer = document.getElementById("planner-announcer")
    if (announcer) announcer.textContent = element.textContent.trim()
  }

  busyTargetConnected() {
    this.clearTimers()
    this.timers = [
      window.setTimeout(() => this.refresh(false), QUICK_CHECK_MS),
      window.setTimeout(() => this.refresh(true), STALL_CHECK_MS)
    ]
  }

  busyTargetDisconnected() {
    this.clearTimers()
  }

  disconnect() {
    this.clearTimers()
  }

  clearTimers() {
    this.timers?.forEach(window.clearTimeout)
    this.timers = []
  }

  // Replaces the frame only when there is news: a finished answer, or (when forced) a stalled job to show Retry.
  async refresh(force) {
    if (!this.element.isConnected) return
    try {
      const response = await fetch(this.urlValue, {
        headers: { "Turbo-Frame": this.element.id, "Accept": "text/html" },
        credentials: "same-origin"
      })
      if (!response.ok) return
      const document = new DOMParser().parseFromString(await response.text(), "text/html")
      const frame = document.getElementById(this.element.id)
      if (!this.element.isConnected) return
      if (!frame && response.redirected) {
        window.location.assign(response.url)
        return
      }
      if (frame && (force || frame.dataset.mealPlannerBusyValue !== "true")) this.element.replaceWith(frame)
    } catch (_error) {
      // A dropped connection leaves the current preview readable; the broadcast can still arrive.
    }
  }
}
