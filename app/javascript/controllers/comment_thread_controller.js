import { Controller } from "@hotwired/stimulus"

// Keeps row-level comments out of the layout until someone chooses them from the row menu.
export default class extends Controller {
  static targets = ["panel", "trigger"]

  toggle(event) {
    event.preventDefault()
    event.currentTarget.closest("details")?.removeAttribute("open")
    this.setOpen(this.panelTarget.hidden)
  }

  close() {
    this.setOpen(false)
    this.triggerTarget?.focus()
  }

  setOpen(open) {
    this.panelTarget.hidden = !open
    this.triggerTargets.forEach((trigger) => trigger.setAttribute("aria-expanded", open))
    if (open) requestAnimationFrame(() => this.panelTarget.querySelector("trix-editor, textarea")?.focus())
  }
}
