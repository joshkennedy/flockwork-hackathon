import { Controller } from "@hotwired/stimulus"
import { toast } from "ding"

export default class extends Controller {
  static targets = [ "input" ]
  static values = {
    key: String,
    maxBytes: Number,
    maxSizeLabel: String,
    acceptedTypes: Array,
    acceptedExtensions: Array,
    typeError: String
  }

  validate(event) {
    const file = this.file(event)
    const error = this.validationError(file)
    if (!error) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.inputTargets.forEach((input) => { input.value = "" })
    toast.error(error)
  }

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

  validationError(file) {
    if (!file) return null
    if (this.hasMaxBytesValue && file.size > this.maxBytesValue) {
      return `${file.name} is too large. Choose a file ${this.maxSizeLabelValue} or smaller.`
    }
    if (this.hasTypeErrorValue && !this.accepts(file)) return this.typeErrorValue

    return null
  }

  accepts(file) {
    const type = file.type.toLowerCase()
    const name = file.name.toLowerCase()
    return this.acceptedTypesValue.includes(type) || this.acceptedExtensionsValue.some((extension) => name.endsWith(extension))
  }

  get loadingTitle() {
    return `Uploading ${this.filename}…`
  }
}
