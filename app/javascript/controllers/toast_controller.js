import { Controller } from "@hotwired/stimulus"

// One flash toast. It arrives in the page's hidden #flash holder and does nothing until the toasts controller
// moves it onto the permanent #toasts stack. Notices leave on their own; alerts (dismissAfter 0) stay until
// dismissed. The deadline lives on the element so a reconnect (the stack is carried across navigations) does
// not restart the timer.
export default class extends Controller {
  static values = { dismissAfter: Number }

  connect() {
    const stack = this.element.parentElement
    if (stack?.id !== "toasts" || this.dismissAfterValue <= 0) return

    this.element.dataset.until ||= Date.now() + this.dismissAfterValue
    if (stack.hasAttribute("data-expanded")) this.pause()
    else this.start()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  start() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.dismiss(), this.element.dataset.until - Date.now())
  }

  pause() {
    if (!this.element.dataset.until || this.element.dataset.left) return
    clearTimeout(this.timer)
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
