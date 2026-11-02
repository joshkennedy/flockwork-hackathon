import { Controller } from "@hotwired/stimulus"

// Recolors the lockup preview as an Admin picks a preset or a custom color.
export default class extends Controller {
  static targets = ["preview", "custom", "customChoice"]

  pickCustom() {
    this.customChoiceTarget.checked = true
    this.update()
  }

  update() {
    const checked = this.element.querySelector("input[name='organization[mark_color_choice]']:checked")
    if (!checked) return
    const color = checked.value === "custom" ? this.customTarget.value : checked.value
    this.previewTarget.style.setProperty("--color-mark", color)
  }
}
