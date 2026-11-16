import { Controller } from "@hotwired/stimulus"
import { mountToaster, toast } from "ding"

export default class extends Controller {
  connect() {
    this.mount()
    this.consume = () => this.consumeEntries()
    document.addEventListener("turbo:render", this.consume)
    document.addEventListener("turbo:frame-render", this.consume)
    this.themeObserver = new MutationObserver(this.syncConfiguration)
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: [ "data-dark" ] })
    this.consumeEntries()
  }

  disconnect() {
    document.removeEventListener("turbo:render", this.consume)
    document.removeEventListener("turbo:frame-render", this.consume)
    this.themeObserver?.disconnect()
    this.unmount?.()
    this.unmount = null
  }

  mount() {
    if (this.unmount) return

    this.unmount = mountToaster(this.configuration)
    const viewport = document.body.querySelector(":scope > .tst-viewport")
    if (viewport) {
      viewport.style.fontFamily = "var(--font-sans)"
      viewport.style.setProperty("--tst-shadow", "var(--shadow-float)")
      this.element.append(viewport)
    }
    if (!document.querySelector("style[data-flockwork-ding]")) {
      const style = document.createElement("style")
      style.dataset.flockworkDing = ""
      // Public pages have no fixed bar, so there the toast keeps Ding's top edge instead of clearing the app's.
      style.textContent = "@media (max-width:639px){body:not([data-public-layout]) .tst-viewport[data-position^=top] .tst-slot{top:calc(72px + env(safe-area-inset-top,0px))}}"
      document.head.append(style)
    }
  }

  syncConfiguration = () => {
    toast.configure(this.configuration)
  }

  consumeEntries() {
    document.querySelectorAll("[data-toast-entry]").forEach((entry) => {
      const message = entry.textContent.trim()
      const action = entry.dataset.toastActionPath ? {
        label: entry.dataset.toastActionLabel,
        onClick: () => this.submitAction(entry.dataset.toastActionPath, entry.dataset.toastActionMethod)
      } : undefined
      if (message) toast[entry.dataset.toastKind === "alert" ? "error" : "success"](message, { action })
      entry.remove()
    })
  }

  submitAction(path, method) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = path
    form.hidden = true

    const methodField = document.createElement("input")
    methodField.type = "hidden"
    methodField.name = "_method"
    methodField.value = method
    form.append(methodField)

    const token = document.querySelector("meta[name=csrf-token]")?.content
    if (token) {
      const tokenField = document.createElement("input")
      tokenField.type = "hidden"
      tokenField.name = "authenticity_token"
      tokenField.value = token
      form.append(tokenField)
    }

    document.body.append(form)
    form.requestSubmit()
  }

  get configuration() {
    return {
      position: "top-center",
      theme: document.documentElement.hasAttribute("data-dark") ? "dark" : "light"
    }
  }
}
