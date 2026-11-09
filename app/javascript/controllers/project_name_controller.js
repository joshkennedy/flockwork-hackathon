import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "field", "form" ]

  formTargetConnected() {
    this.savedName = this.fieldTarget.value
    this.saving = false
    const next = this.nextSubmission
    this.nextSubmission = null
    if (!next || this.savedName !== this.pendingName) return

    // A title save advances the revision. Resume the user's action from the fresh form.
    queueMicrotask(() => {
      const form = Array.from(this.element.querySelectorAll("form")).find(form => form.action === next.action)
      if (!form) return
      for (const [name, value] of next.values) {
        if (["expected_revision", "authenticity_token", "project[name]"].includes(name)) continue
        const field = form.elements.namedItem(name)
        if (field && "value" in field) field.value = value
      }
      form.requestSubmit()
    })
  }

  save(event) {
    if (event.type === "keydown") {
      if (event.isComposing) return
      event.preventDefault()
    }
    if (this.saving || this.fieldTarget.disabled) return

    const name = this.fieldTarget.value.trim()
    if (!name) {
      this.fieldTarget.value = this.savedName
      return
    }
    if (name === this.savedName) return

    this.fieldTarget.value = name
    this.pendingName = name
    this.saving = true
    this.fieldTarget.readOnly = true
    this.formTarget.requestSubmit()
  }

  waitForSave(event) {
    if (!this.saving || event.target === this.formTarget) return
    event.preventDefault()
    event.stopImmediatePropagation()
    this.nextSubmission = { action: event.target.action, values: Array.from(new FormData(event.target)) }
  }

  submitted(event) {
    if (event.target !== this.formTarget || event.detail.success) return
    this.saving = false
    this.fieldTarget.readOnly = false
  }
}
