import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "query"]

  keepOpen(event) {
    if (this.hasDialogTarget && this.dialogTarget.open && event.target === this.dialogTarget) event.preventDefault()
  }

  shortcut(event) {
    if (!(event.metaKey || event.ctrlKey) || event.key.toLowerCase() !== "k") return
    this.open(event)
  }

  open(event) {
    if (!this.hasDialogTarget) return
    event.preventDefault()
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
    this.queryTarget.focus()
    this.queryTarget.select()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
