import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submitted(event) {
    if (!event.detail.success) return

    this.element.querySelector("trix-editor")?.editor.loadHTML("")
    this.element.querySelector("[role=alert]")?.remove()
    this.element.reset()
  }
}
