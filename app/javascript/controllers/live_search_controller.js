import { Controller } from "@hotwired/stimulus"

// Submits a GET search form as the person types; results land in the form's turbo frame.
export default class extends Controller {
  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 200)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
