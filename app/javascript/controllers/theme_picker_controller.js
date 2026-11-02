import { Controller } from "@hotwired/stimulus"

// Applies a church's theme the moment an Admin picks it, then saves it.
export default class extends Controller {
  static targets = ["custom", "customChoice"]

  pick() {
    this.apply()
    this.element.requestSubmit()
  }

  // Dragging in the native picker recolors live; the save waits for its change event.
  previewCustom() {
    this.customChoiceTarget.checked = true
    this.apply()
  }

  apply() {
    const checked = this.element.querySelector("input[name='organization[mark_color_choice]']:checked")
    if (!checked) return
    const color = checked.value === "custom" ? this.customTarget.value : checked.value
    document.body.style.setProperty("--color-mark", color)
    const favicon = document.querySelector("link[rel=icon][type='image/svg+xml']")
    if (favicon) favicon.href = `/icon.svg?c=${color.replace("#", "").toUpperCase()}`
  }
}
