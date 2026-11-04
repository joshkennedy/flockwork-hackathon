import { Controller } from "@hotwired/stimulus"

// One flash toast. It arrives in the page's hidden #flash holder and does nothing until the toasts controller
// moves it onto the permanent #toasts stack. Notices leave on their own; alerts (dismissAfter 0) stay until
// dismissed. The deadline lives on the element so a reconnect (the stack is carried across navigations) does
// not restart the timer.
export default class extends Controller {
  static values = { dismissAfter: Number }
  static targets = ["progress"]

  connect() {
    const stack = this.element.parentElement
    if (stack?.id !== "toasts" || this.dismissAfterValue <= 0) return

    this.element.dataset.until ||= Date.now() + this.dismissAfterValue
    if (this.hasProgressTarget) {
      const remaining = Number(this.element.dataset.left || this.element.dataset.until - Date.now())
      this.progressTarget.style.width = `${Math.max(0, Math.min(1, remaining / this.dismissAfterValue)) * 100}%`
    }
    if (stack.hasAttribute("data-expanded")) this.pause()
    else this.start()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.progressAnimation?.cancel()
  }

  start() {
    clearTimeout(this.timer)
    const remaining = Math.max(0, this.element.dataset.until - Date.now())
    this.timer = setTimeout(() => this.dismiss(), remaining)
    this.progressAnimation?.cancel()
    if (this.hasProgressTarget && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.progressAnimation = this.progressTarget.animate(
        [{ width: `${Math.min(1, remaining / this.dismissAfterValue) * 100}%` }, { width: "0%" }],
        { duration: remaining, easing: "linear", fill: "forwards" }
      )
    }
  }

  pause() {
    if (!this.element.dataset.until || this.element.dataset.left) return
    clearTimeout(this.timer)
    this.progressAnimation?.pause()
    this.element.dataset.left = this.element.dataset.until - Date.now()
  }

  resume() {
    if (!this.element.dataset.left) return
    this.element.dataset.until = Date.now() + Number(this.element.dataset.left)
    delete this.element.dataset.left
    this.start()
  }

  dismiss() {
    this.element.remove()
  }
}
