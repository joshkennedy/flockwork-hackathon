import { Controller } from "@hotwired/stimulus"
import { toast } from "ding"

export default class extends Controller {
  static targets = ["dialog", "query", "form", "results", "container", "status", "shortcut"]

  connect() {
    this.shortcutTargets.forEach(key => key.textContent = /Mac|iPhone|iPad/.test(navigator.platform) ? "⌘ K" : "Ctrl K")
  }

  disconnect() {
    this.cancel()
  }

  cancel() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.version = (this.version || 0) + 1
  }

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
    if (!this.dialogTarget.open) {
      this.trigger = document.activeElement
      this.dialogTarget.showModal()
      this.load()
    }
    this.queryTarget.focus()
    this.queryTarget.select()
  }

  close() {
    if (this.hasDialogTarget) this.dialogTarget.close()
  }

  closed() {
    this.cancel()
    if (this.trigger?.isConnected) this.trigger.focus()
  }

  search(event) {
    if (event.isComposing) return
    this.cancel()
    this.statusTarget.textContent = "Searching…"
    this.containerTarget.inert = true
    this.containerTarget.setAttribute("aria-busy", "true")
    this.timer = setTimeout(() => this.load(), 80)
  }

  submit(event) {
    event.preventDefault()
    this.cancel()
    this.load()
  }

  async load() {
    this.cancel()
    const version = this.version
    this.request = new AbortController()
    const url = new URL(this.formTarget.action)
    url.searchParams.set("query", this.queryTarget.value)
    this.containerTarget.inert = true
    this.containerTarget.setAttribute("aria-busy", "true")
    try {
      const response = await fetch(url, { headers: { "Turbo-Frame": "search-results" }, signal: this.request.signal })
      if (!response.ok || response.redirected) throw new Error("Search unavailable")
      const html = new DOMParser().parseFromString(await response.text(), "text/html").querySelector("#search-results")
      if (!html) throw new Error("Missing results")
      if (version !== this.version) return
      this.resultsTarget.replaceWith(html)
      this.containerTarget.scrollTop = 0
      const count = html.querySelectorAll("a").length
      this.statusTarget.textContent = this.queryTarget.value.trim() ? `${count} ${count === 1 ? "result" : "results"}` : "Search by name or title"
    } catch (error) {
      if (error.name === "AbortError" || version !== this.version) return
      this.resultsTarget.replaceChildren()
      toast.error("Search couldn’t load. Press Enter to try again.")
      this.statusTarget.textContent = "Search unavailable"
    } finally {
      if (version === this.version) {
        this.containerTarget.removeAttribute("aria-busy")
        this.containerTarget.inert = false
      }
    }
  }

  navigate(event) {
    if (event.isComposing || event.metaKey || event.ctrlKey || event.altKey) return
    if (this.containerTarget.hasAttribute("aria-busy")) return
    const links = Array.from(this.resultsTarget.querySelectorAll("a"))
    const index = links.indexOf(document.activeElement)
    if (["ArrowDown", "ArrowUp"].includes(event.key) && links.length) {
      event.preventDefault()
      const next = event.key === "ArrowDown" ? (index + 1) % links.length : (index <= 0 ? links.length - 1 : index - 1)
      links[next].focus()
      links[next].scrollIntoView({ block: "nearest" })
    } else if (event.key === "Enter" && event.target === this.queryTarget && links.length && !this.containerTarget.hasAttribute("aria-busy")) {
      event.preventDefault()
      links[0].click()
    }
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
