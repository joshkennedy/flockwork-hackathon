import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // An autofocused field takes focus before this connects, so its first focus event is already gone.
  connect() {
    if (document.activeElement === this.element) this.all()
  }

  all() {
    this.element.select()
  }
}
