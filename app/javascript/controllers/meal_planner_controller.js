import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]
  static values = { busy: Boolean, url: String }

  // Swapped-in live regions are rarely announced, so copy status text into the stable one.
  statusTargetConnected(element) {
    const announcer = document.getElementById("planner-announcer")
    if (announcer) announcer.textContent = element.textContent.trim()
  }

  connect() {
    if (this.busyValue) this.timer = window.setTimeout(() => this.refresh(), 3000)
  }

  disconnect() {
    window.clearTimeout(this.timer)
  }

  async refresh() {
    if (!this.element.isConnected || !this.busyValue) return
    try {
      const response = await fetch(this.urlValue, {
        headers: { "Turbo-Frame": this.element.id, "Accept": "text/html" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error("Could not refresh planning")
      const document = new DOMParser().parseFromString(await response.text(), "text/html")
      const frame = document.getElementById(this.element.id)
      if (!this.element.isConnected) return
      if (!frame && response.redirected) {
        window.location.assign(response.url)
        return
      }
      if (frame) {
        // Replace the frame itself so the new persisted busy state controls the next poll.
        this.element.replaceWith(frame)
        return
      }
    } catch (_error) {
      // A dropped connection leaves the current preview readable while polling retries.
    }
    if (this.element.isConnected) this.timer = window.setTimeout(() => this.refresh(), 3000)
  }
}
