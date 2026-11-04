import { Controller } from "@hotwired/stimulus"

// Shows one panel at a time. Every panel is server-rendered so forms keep working,
// and the last tab is remembered per page because form redirects land on the bare URL.
export default class extends Controller {
  static targets = ["tab", "panel"]
  // Set when the URL itself picks the tab (e.g. /team), so a remembered tab must not override it.
  static values = { explicit: Boolean }

  connect() {
    const anchored = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)))
    const fromHash = anchored && this.panelTargets.find((panel) => panel.contains(anchored))
    const stored = !this.explicitValue && this.panelTargets.find((panel) => panel.dataset.tabsName === this.remembered)
    const panel = fromHash || stored
    if (panel) this.show(panel.dataset.tabsName)
    this.element.addEventListener("turbo:before-morph-attribute", this.keepShownTab)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.keepShownTab)
  }

  // A morph refresh keeps this element, so connect() never re-runs; keep the shown tab instead of the server default.
  keepShownTab = (event) => {
    const { target, detail } = event
    if ((detail.attributeName === "hidden" && this.panelTargets.includes(target)) ||
        (detail.attributeName === "aria-current" && this.tabTargets.includes(target))) event.preventDefault()
  }

  select(event) {
    event.preventDefault()
    const name = event.currentTarget.dataset.tabsName
    this.show(name)
    this.remembered = name
  }

  show(name) {
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.tabsName !== name })
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-current", tab.dataset.tabsName === name))
  }

  get remembered() {
    try { return sessionStorage.getItem(this.storageKey) } catch { return null }
  }

  set remembered(name) {
    try { sessionStorage.setItem(this.storageKey, name) } catch {}
  }

  get storageKey() {
    return `tabs:${location.pathname}`
  }
}
