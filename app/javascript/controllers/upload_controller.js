import { Controller } from "@hotwired/stimulus"
import { toast } from "ding"

export default class extends Controller {
  static targets = [ "input" ]
  static values = { key: String }

  start(event) {
    const file = this.file(event)
    if (!file) return

    this.filename = file.name
    const patch = {
      type: "loading",
      title: this.loadingTitle,
      description: "",
      action: null,
      duration: 0,
      progress: event.type === "direct-upload:start" ? 0 : null
    }
    if (this.toastId) toast.update(this.toastId, patch)
    else this.toastId = toast.loading(this.loadingTitle, patch)
  }

  progress(event) {
    if (!this.toastId) this.start(event)
    toast.update(this.toastId, { progress: event.detail.progress / 100 })
  }

  directError(event) {
    event.preventDefault()
    this.fail(event.detail.error || "The upload failed.")
  }

  finish(event) {
    if (!this.toastId) return
    if (event.detail.success) {
      toast.update(this.toastId, {
        type: "success",
        title: `Uploaded ${this.filename}`,
        description: "",
        progress: null,
        action: null,
        duration: 5000
      })
    } else {
      this.fail("The upload failed. Check the form and try again.")
    }
  }

  fail(reason) {
    toast.update(this.toastId, {
      type: "error",
      title: `Couldn’t upload ${this.filename}`,
      description: reason,
      progress: null,
      action: { label: "Try Again", onClick: () => this.retry() },
      duration: 0
    })
  }

  retry() {
    const form = this.element.isConnected ? this.element : document.querySelector(`[data-upload-key-value="${CSS.escape(this.keyValue)}"]`)
    form?.requestSubmit()
    return { type: "loading", title: this.loadingTitle, description: "", action: null, progress: null, duration: 0 }
  }

  file(event) {
    if (event.target?.files?.[0]) return event.target.files[0]
    return this.inputTargets.find((input) => input.files?.length)?.files[0]
  }

  get loadingTitle() {
    return `Uploading ${this.filename}…`
  }
}
