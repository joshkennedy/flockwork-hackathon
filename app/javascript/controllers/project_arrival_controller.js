import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { targetId: String }

  connect() {
    this.scheduleArrival()
  }

  disconnect() {
    window.cancelAnimationFrame(this.frame)
  }

  scheduleArrival() {
    window.cancelAnimationFrame(this.frame)
    // Turbo restores scroll after rendering; place the result after that restoration.
    this.frame = window.requestAnimationFrame(() => {
      this.frame = window.requestAnimationFrame(() => this.arrive())
    })
  }

  arrive() {
    if (!this.element.isConnected) return
    const target = document.getElementById(this.targetIdValue)
    if (!target) return
    target.tabIndex = -1
    target.focus({ preventScroll: true })
    const section = target.closest("section") || target
    section.scrollIntoView({ block: "start" })
  }
}
