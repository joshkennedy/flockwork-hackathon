import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 200)
  }

  // A filter that also changes the counts and links outside the results frame reloads the whole page.
  submitPage() {
    clearTimeout(this.timer)
    this.element.dataset.turboFrame = "_top"
    this.element.requestSubmit()
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
