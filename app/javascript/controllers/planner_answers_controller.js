import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["answer"]

  choose(event) {
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey || event.repeat) return
    if (event.target.closest("input, textarea, select, [contenteditable], trix-editor")) return
    if (!/^[1-9]$/.test(event.key)) return

    const answer = this.answerTargets[Number(event.key) - 1]
    if (!answer || answer.disabled || !answer.getClientRects().length) return

    event.preventDefault()
    answer.focus()
    answer.click()
  }
}
