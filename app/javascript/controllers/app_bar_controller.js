import { Controller } from "@hotwired/stimulus"

// Once the page scrolls, a panel-colored band fades in behind the floating bar's shell so content
// passing under it doesn't show in the gap above the pill.
export default class extends Controller {
  connect() {
    this.update = () => this.element.toggleAttribute("data-scrolled", window.scrollY > 4)
    this.update()
    window.addEventListener("scroll", this.update, { passive: true })
    // A morph refresh would strip the attribute while the page stays scrolled.
    this.keep = (event) => { if (event.target === this.element && event.detail.attributeName === "data-scrolled") event.preventDefault() }
    this.element.addEventListener("turbo:before-morph-attribute", this.keep)
  }

  disconnect() {
    window.removeEventListener("scroll", this.update)
    this.element.removeEventListener("turbo:before-morph-attribute", this.keep)
  }
}
