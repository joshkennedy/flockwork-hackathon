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

  submitted(event) {
    if (!event.detail.success) return

    this.dialogTarget.close()
    window.Turbo.visit(event.detail.fetchResponse.response.url)
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
