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
      style.textContent = "@media (max-width:639px){.tst-viewport[data-position^=top] .tst-slot{top:calc(72px + env(safe-area-inset-top,0px))}}"
      document.head.append(style)
    }
  }

  syncConfiguration = () => {
    toast.configure(this.configuration)
  }

  consumeEntries() {
    document.querySelectorAll("[data-toast-entry]").forEach((entry) => {
      const message = entry.textContent.trim()
      if (message) toast[entry.dataset.toastKind === "alert" ? "error" : "success"](message)
      entry.remove()
    })
  }

  get configuration() {
    return {
      position: "top-center",
      theme: document.documentElement.hasAttribute("data-dark") ? "dark" : "light"
    }
  }
}
