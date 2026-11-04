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
    else this.scrollTabIntoView(this.tabTargets.find((tab) => tab.getAttribute("aria-current") === "true"))
    this.tabBar = this.element.querySelector(".project-tab-strip .tab-bar")
    this.tabBar?.addEventListener("scroll", this.updateTabOverflow)
    window.addEventListener("resize", this.updateTabOverflow)
    requestAnimationFrame(this.updateTabOverflow)
    this.element.addEventListener("turbo:before-morph-attribute", this.keepShownTab)
    window.addEventListener("hashchange", this.selectHash)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.keepShownTab)
    this.tabBar?.removeEventListener("scroll", this.updateTabOverflow)
    window.removeEventListener("resize", this.updateTabOverflow)
    window.removeEventListener("hashchange", this.selectHash)
  }

  selectHash = () => {
    const anchored = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)))
    const panel = anchored && this.panelTargets.find((panel) => panel.contains(anchored))
    if (panel) {
      this.show(panel.dataset.tabsName)
      this.remembered = panel.dataset.tabsName
    }
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
    this.scrollTabIntoView(this.tabTargets.find((tab) => tab.dataset.tabsName === name))
  }

  scrollTabIntoView(tab) {
    if (!tab) return

    const bar = tab.parentElement
    const left = tab.offsetLeft
    const right = left + tab.offsetWidth
    if (left < bar.scrollLeft) bar.scrollLeft = left
    else if (right > bar.scrollLeft + bar.clientWidth - 40) bar.scrollLeft = right - bar.clientWidth + 40
    requestAnimationFrame(this.updateTabOverflow)
  }

  updateTabOverflow = () => {
    const bar = this.tabBar || this.element.querySelector(".project-tab-strip .tab-bar")
    if (!bar) return

    bar.parentElement.dataset.atEnd = bar.scrollLeft + bar.clientWidth >= bar.scrollWidth - 1
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
