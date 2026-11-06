import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 200)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
