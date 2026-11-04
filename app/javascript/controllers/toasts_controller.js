import { Controller } from "@hotwired/stimulus"

const PEEK = 10 // px each older toast shows below the one in front
const GAP = 8 // px between toasts when the pile is spread out
const VISIBLE = 3

// The toast pile: newest in front, up to two older ones peeking out below. Hovering or focusing spreads
// the pile into a list and pauses every timer.
export default class extends Controller {
  connect() {
    this.observer = new MutationObserver(() => this.layout())
    this.observer.observe(this.element, { childList: true })
    // New flash renders into #flash; pull it onto the stack once the render (visit or morph) has settled, because
    // during the body swap this permanent element is briefly out of the document.
    this.adopt = () => document.querySelectorAll("#flash > .toast").forEach((toast) => this.element.prepend(toast))
    document.addEventListener("turbo:render", this.adopt)
    this.adopt()
    this.layout()
  }

  disconnect() {
    this.observer.disconnect()
    document.removeEventListener("turbo:render", this.adopt)
  }

  expand() {
    if (this.expanded) return
    this.expanded = true
    this.element.toggleAttribute("data-expanded", true)
    this.toasts.forEach((toast) => toast.dispatchEvent(new CustomEvent("toast:pause")))
    this.layout()
  }

  collapse(event) {
    if (!this.expanded || this.element.contains(event.relatedTarget)) return
    this.expanded = false
    this.element.removeAttribute("data-expanded")
    this.toasts.forEach((toast) => toast.dispatchEvent(new CustomEvent("toast:resume")))
    this.layout()
  }

  layout() {
    const toasts = this.toasts
    // Measure each toast once, at its natural height, before the pile clips it.
    toasts.forEach((toast) => { toast.dataset.height ||= toast.offsetHeight })
    const front = Number(toasts[0]?.dataset.height || 0)

    let y = 0
    toasts.forEach((toast, index) => {
      const height = Number(toast.dataset.height)
      const behind = !this.expanded && index > 0
      toast.style.zIndex = toasts.length - index
      toast.style.height = `${behind ? front : height}px`
      toast.style.transform = this.expanded
        ? `translateY(${y}px)`
        : `translateY(${index * PEEK}px) scale(${1 - index * 0.05})`
      toast.toggleAttribute("data-behind", behind)
      toast.toggleAttribute("data-beyond", index >= VISIBLE)
      y += height + GAP
    })
    if (!toasts.length) this.collapse({ relatedTarget: null })
    // The stack's own height is the hover area, so the gaps of a spread pile do not end the hover.
    this.element.style.height = `${this.expanded ? Math.max(y - GAP, 0) : front + Math.min(toasts.length - 1, VISIBLE - 1) * PEEK}px`
  }

  get toasts() {
    return [ ...this.element.children ]
  }
}
