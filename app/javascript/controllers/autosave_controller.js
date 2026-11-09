import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "submit" ]

  connect() {
    this.submitTarget.hidden = true
  }

  save() {
    this.element.requestSubmit(this.submitTarget)
  }
}
