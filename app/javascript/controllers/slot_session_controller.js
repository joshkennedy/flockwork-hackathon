import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date", "session"]

  connect() {
    this.sync()
  }

  sync() {
    const option = this.sessionTarget.selectedOptions[0]
    const linked = option?.value && option.dataset.date

    if (linked) this.dateTarget.value = option.dataset.date
    this.dateTarget.readOnly = Boolean(linked)
  }
}
