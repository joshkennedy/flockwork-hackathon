import { Controller } from "@hotwired/stimulus"

// Choosing or dropping an image submits it straight away. The server checks the real type and size.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }

  over(event) {
    event.preventDefault()
    this.element.dataset.dragging = ""
  }

  leave() {
    delete this.element.dataset.dragging
  }

  drop(event) {
    event.preventDefault()
    delete this.element.dataset.dragging
    this.element.querySelector("input[type=file]").files = event.dataTransfer.files
    this.submit()
  }
}
