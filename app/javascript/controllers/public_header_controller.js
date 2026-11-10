import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.update()
  }

  update() {
    this.element.toggleAttribute("data-at-top", window.scrollY <= 8)
  }
}
