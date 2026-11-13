import { Controller } from "@hotwired/stimulus"
import { mountToaster, toast } from "ding"

// A held spot confirms with Ding's check drawn in sunlit, the kept check, instead of the generic green.
const KEPT_CHECK = "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#F5B000" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18"/><path d="M7.9 12.4l3 3 5.3-6"/></svg>')

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
      style.textContent = "@media (max-width:639px){.tst-viewport[data-position^=top] .tst-slot{top:calc(72px + env(safe-area-inset-top,0px))}}.tst-media{width:22px;height:22px;border-radius:0;outline:none}"
      document.head.append(style)
    }
  }

  syncConfiguration = () => {
    toast.configure(this.configuration)
  }

  consumeEntries() {
    document.querySelectorAll("[data-toast-entry]").forEach((entry) => {
      const message = entry.textContent.trim()
      const kind = entry.dataset.toastKind
      if (message) toast[kind === "alert" ? "error" : "success"](message, kind === "claimed" ? { image: KEPT_CHECK } : undefined)
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
