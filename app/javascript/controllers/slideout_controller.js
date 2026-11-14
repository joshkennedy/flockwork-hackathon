import { Controller } from "@hotwired/stimulus"

// A side panel on a native <dialog>: showModal gives focus trapping, Escape and inert page for free.
// The trigger stays a real link, so it still works opened in a new tab or without JS.
export default class extends Controller {
  static targets = ["dialog", "frame", "title"]

  connect() {
    if (this.hasFrameTarget) this.placeholder = this.frameTarget.innerHTML
    this.restoreFocus = this.restoreFocus.bind(this)
    this.dialogTarget.addEventListener("close", this.restoreFocus)
  }

  disconnect() {
    this.dialogTarget.removeEventListener("close", this.restoreFocus)
  }

  open(event) {
    event.preventDefault()
    this.trigger = event.currentTarget
    // Swap back to the placeholder first so a different form never flashes the previous one.
    if (this.hasFrameTarget && this.frameTarget.src !== event.currentTarget.href) {
      this.frameTarget.innerHTML = this.placeholder
      this.frameTarget.src = event.currentTarget.href
    }
    if (this.hasTitleTarget && event.params.title) this.titleTarget.textContent = event.params.title
    event.currentTarget.closest("details")?.removeAttribute("open")
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  submitted(event) {
    if (!event.detail.success) return

    this.dialogTarget.close()
    window.Turbo.visit(event.detail.fetchResponse.response.url)
  }

  // A click that lands on the dialog element itself is on the backdrop, outside the panel.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  restoreFocus() {
    if (this.trigger?.isConnected) this.trigger.focus()
    this.trigger = null
  }
}
