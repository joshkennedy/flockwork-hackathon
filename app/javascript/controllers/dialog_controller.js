import { Controller } from "@hotwired/stimulus"

// A centered native dialog. Trigger links remain useful without JavaScript.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event.preventDefault()
    event.currentTarget.closest("details")?.removeAttribute("open")
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
