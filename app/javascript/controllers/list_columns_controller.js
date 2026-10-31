import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "row", "template"]
  static values = { nextIndex: Number }

  connect() {
    this.updateRemoveButtons()
  }

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("NEW_INDEX", this.nextIndexValue)
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.nextIndexValue += 1
    this.updateRemoveButtons()
    this.rowTargets.at(-1)?.querySelector("input")?.focus()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-list-columns-target='row']")
    if (!row || this.rowTargets.length <= 1) return
    const nextFocus = row.previousElementSibling?.querySelector("input") || row.nextElementSibling?.querySelector("input")
    row.remove()
    this.updateRemoveButtons()
    nextFocus?.focus()
  }

  updateRemoveButtons() {
    const onlyOne = this.rowTargets.length <= 1
    this.rowTargets.forEach(row => {
      const button = row.querySelector("[data-action='list-columns#remove']")
      if (button) button.disabled = onlyOne
    })
  }
}
