import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]
  static values = { detect: Boolean }

  connect() {
    if (!this.detectValue) return

    const browserZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    const option = Array.from(this.selectTarget.options).find(({ value }) => value === browserZone)
    if (option) this.selectTarget.value = browserZone
  }
}
