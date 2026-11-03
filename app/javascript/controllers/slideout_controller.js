import { Controller } from "@hotwired/stimulus"

// A side panel on a native <dialog>: showModal gives focus trapping, Escape and inert page for free.
// The trigger stays a real link, so it still works opened in a new tab or without JS.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // A click that lands on the dialog element itself is on the backdrop, outside the panel.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
