import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "preview", "add", "status", "error", "errorText", "editingHint"]
  static values = { url: String, revision: Number }

  initialize() {
    this.previewToggle = event => {
      if (!event.target.matches(".meal-slot-editor")) return
      const editing = this.previewTarget.querySelector(".meal-slot-editor[open]")
      if (editing) this.positionEditor(editing)
      if (!editing && this.pendingPreview) {
        const preview = this.pendingPreview
        this.pendingPreview = null
        this.previewTarget.innerHTML = preview
      }
      this.addTarget.disabled = !!editing || this.dirty || !!this.saving || !this.addable
      this.showEditingHint(editing)
    }
  }

  formTargetConnected(form) {
    // Turbo replaces frame children after a row edit, while the outer controller survives.
    this.revisionValue = Number(form.querySelector('[name="expected_revision"]').value)
    clearTimeout(this.timer)
    this.dirty = false
    this.submitting = false
    this.resubmitting = false
    this.addable = !this.addTarget.disabled
    this.pendingPreview = null
    this.focusAfterEdit = null
  }

  previewTargetConnected(preview) {
    preview.addEventListener("toggle", this.previewToggle, true)
  }

  previewTargetDisconnected(preview) {
    preview.removeEventListener("toggle", this.previewToggle, true)
  }

  connect() {
    this.saving = null
    this.beforeUnload = event => {
      if (!this.dirty && !this.saving) return
      event.preventDefault()
      event.returnValue = ""
    }
    window.addEventListener("beforeunload", this.beforeUnload)
    this.beforeVisit = event => {
      if (!this.dirty && !this.saving) return
      event.preventDefault()
      const destination = event.detail.url
      this.save().then(saved => { if (saved) window.Turbo.visit(destination) })
    }
    document.addEventListener("turbo:before-visit", this.beforeVisit)
    this.repositionEditor = () => {
      const editor = this.previewTarget.querySelector(".meal-slot-editor[open]")
      if (editor) this.positionEditor(editor)
    }
    window.addEventListener("resize", this.repositionEditor)
    window.addEventListener("scroll", this.repositionEditor, true)
    window.visualViewport?.addEventListener("resize", this.repositionEditor)
  }

  disconnect() {
    clearTimeout(this.timer)
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
    window.removeEventListener("resize", this.repositionEditor)
    window.removeEventListener("scroll", this.repositionEditor, true)
    window.visualViewport?.removeEventListener("resize", this.repositionEditor)
  }

  change() {
    this.dirty = true
    this.addTarget.disabled = true
    this.statusTarget.textContent = "Saving…"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), 350)
  }

  save() {
    clearTimeout(this.timer)
    if (!this.saving) this.saving = this.persistChanges().finally(() => { this.saving = null })
    return this.saving
  }

  async persistChanges() {
    while (this.dirty) {
      if (!await this.persist()) return false
    }
    return true
  }

  async persist() {
    const body = new FormData(this.formTarget)
    body.set("expected_revision", this.revisionValue)
    this.dirty = false
    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body
      })
      if (!response.headers.get("Content-Type")?.includes("application/json")) {
        throw new Error("Couldn’t save these details. Reload the saved setup and try again.")
      }
      const result = await response.json()
      if (!response.ok) throw new Error(result.error || "Couldn’t save these details. Try again.")
      if (!this.element.isConnected) return true

      this.revisionValue = result.revision
      this.element.querySelectorAll('[name="expected_revision"]').forEach(input => { input.value = result.revision })
      this.errorTarget.hidden = true
      if (!this.dirty) {
        // Keep an open editor connected so bulk saves cannot erase its unsaved fields.
        const editing = this.previewTarget.querySelector(".meal-slot-editor[open]")
        if (this.submitting || editing) {
          this.pendingPreview = result.preview
        } else {
          this.pendingPreview = null
          this.previewTarget.innerHTML = result.preview
        }
        this.addTarget.value = result.count === 1 ? "Add 1 Meal Slot" : `Add ${result.count || ""} Meal Slots`.replace("  ", " ")
        this.addable = result.addable
        this.addTarget.disabled = !result.addable || !!editing
        this.showEditingHint(editing)
        this.statusTarget.textContent = "Changes saved"
      }
      return true
    } catch (error) {
      this.dirty = true
      if (this.element.isConnected) {
        this.statusTarget.textContent = "Changes not saved"
        this.errorTextTarget.textContent = error instanceof TypeError ? "Couldn’t save. Check your connection and try again." :
          error.message || "Couldn’t save these details. Try again."
        this.errorTarget.hidden = false
        this.addTarget.disabled = true
      }
      return false
    }
  }

  async submit(event) {
    if (this.resubmitting || (!this.dirty && !this.saving)) return
    event.preventDefault()
    const form = event.target
    const submitter = event.submitter
    this.submitting = true
    const saved = await this.save()
    this.submitting = false
    if (!saved || !form.isConnected) return

    // A new task lets the original submit event finish before requestSubmit fires again.
    setTimeout(() => {
      if (!form.isConnected) return
      this.resubmitting = true
      form.requestSubmit(submitter)
      this.resubmitting = false
    }, 0)
  }

  async leave(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    const destination = event.currentTarget.href
    if (await this.save()) window.Turbo.visit(destination)
  }

  retry() {
    this.dirty = true
    this.statusTarget.textContent = "Saving…"
    this.save()
  }

  async saveName(event) {
    if (event.isComposing) return
    event.preventDefault()
    const input = event.currentTarget
    if (await this.save()) input.blur()
  }

  showEditingHint(editor) {
    this.editingHintTarget.hidden = !editor
    this.editingHintTarget.textContent = editor ? "Save or cancel the meal you’re editing before adding Meal Slots." : ""
    if (!editor && this.focusAfterEdit) {
      document.getElementById(this.focusAfterEdit)?.querySelector("summary")?.focus()
      this.focusAfterEdit = null
    }
  }

  positionEditor(editor) {
    const panel = editor.querySelector(".meal-setup-slot-popover")
    const trigger = editor.querySelector("summary").getBoundingClientRect()
    const width = Math.min(320, window.innerWidth - 32)
    const anchorLeft = getComputedStyle(editor).direction === "rtl" ? trigger.left : trigger.right - width
    const left = Math.max(16, Math.min(anchorLeft, window.innerWidth - width - 16))
    panel.style.width = `${width}px`
    panel.style.insetInlineEnd = "auto"
    panel.style.right = "auto"
    panel.style.left = `${left - editor.getBoundingClientRect().left}px`
    const viewportTop = window.visualViewport?.offsetTop || 0
    const viewportBottom = viewportTop + (window.visualViewport?.height || window.innerHeight) - (window.innerWidth < 768 ? 80 : 16)
    const top = viewportTop + 16
    panel.style.maxHeight = `${Math.max(48, viewportBottom - top)}px`
    const height = panel.offsetHeight
    const below = viewportBottom - trigger.bottom - 4
    const above = trigger.top - top - 4
    const wantedTop = below >= height || below >= above ? trigger.bottom + 4 : trigger.top - height - 4
    const panelTop = Math.max(top, Math.min(wantedTop, viewportBottom - height))
    panel.style.bottom = "auto"
    panel.style.top = `${panelTop - editor.getBoundingClientRect().top}px`
  }

  cancelEdit(event) {
    const editor = event.currentTarget.closest("details")
    this.focusAfterEdit = editor.closest("article").id
    editor.open = false
  }

  async reload(event) {
    event.preventDefault()
    const destination = event.currentTarget.href
    clearTimeout(this.timer)
    if (this.saving) await this.saving
    this.dirty = false
    window.location.assign(destination)
  }
}
