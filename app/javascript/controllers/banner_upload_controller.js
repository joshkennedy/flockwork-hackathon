import { Controller } from "@hotwired/stimulus"

// Choosing or dropping an image submits it straight away. The server checks the real type and size.
// Drops are always prevented so the browser never opens the file, but only image files light the drop highlight.
export default class extends Controller {
  static targets = [ "input" ]

  pick() {
    this.inputTarget.click()
  }

  submit() {
    this.inputTarget.form.requestSubmit()
  }

  over(event) {
    event.preventDefault()
    if (this.element.hasAttribute("data-repositioning") || !event.dataTransfer?.types.includes("Files")) return

    this.element.dataset.dragging = ""
  }

  leave() {
    delete this.element.dataset.dragging
  }

  drop(event) {
    event.preventDefault()
    delete this.element.dataset.dragging
    if (this.element.hasAttribute("data-repositioning") || !event.dataTransfer.files.length) return

    this.inputTarget.files = event.dataTransfer.files
    this.submit()
  }
}
