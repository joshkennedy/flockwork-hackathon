import { Controller } from "@hotwired/stimulus"

// Plays an element's entrance once, the first time enough of it is on screen.
// CSS hides nothing until this controller marks the element "ready", so the page reads fine without JavaScript.
export default class extends Controller {
  connect() {
    if (!("IntersectionObserver" in window)) return

    this.element.dataset.reveal = "ready"
    // Wait until nearly all of it is on screen, so the part at the bottom is seen entering too.
    // An element taller than the viewport can never reach that, so it reveals once it fills most of the screen.
    this.observer = new IntersectionObserver(([ entry ]) => {
      const fillsScreen = entry.intersectionRect.height >= entry.rootBounds.height * 0.7
      if (entry.intersectionRatio < 0.9 && !fillsScreen) return
      this.element.dataset.reveal = "in"
      this.observer.disconnect()
    }, { threshold: [ 0.5, 0.7, 0.9, 1 ] })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
