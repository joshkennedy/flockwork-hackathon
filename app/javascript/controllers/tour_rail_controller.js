import { Controller } from "@hotwired/stimulus"

// Lights the rail item for whichever tool scene is nearest the middle of the viewport.
export default class extends Controller {
  static targets = ["item", "screen"]

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => { if (entry.isIntersecting) this.light(entry.target.dataset.screen) })
    }, { rootMargin: "-45% 0px -45% 0px", threshold: 0 })
    this.screenTargets.forEach((screen) => this.observer.observe(screen))
    this.light(this.screenTargets[0].dataset.screen)
  }

  disconnect() {
    this.observer.disconnect()
  }

  jump(event) {
    const name = event.params.screen
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.screenTargets.find((screen) => screen.dataset.screen === name)
      .scrollIntoView({ block: "center", behavior: reduced ? "auto" : "smooth" })
    this.light(name)
  }

  light(name) {
    this.itemTargets.forEach((item) => {
      item.setAttribute("aria-pressed", item.dataset.tourRailScreenParam === name)
    })
  }
}
