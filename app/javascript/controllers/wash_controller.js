import { Controller } from "@hotwired/stimulus"

const PROPERTIES = [ "--wash-a", "--wash-b", "--wash-a-x", "--wash-a-y", "--wash-b-x", "--wash-b-y" ]
// The deliberate exception to DESIGN.md's 300ms ceiling: a slow drift between pages.
const DRIFT = { duration: 1600, easing: "cubic-bezier(0.45, 0, 0.25, 1)" }
let previous = null

// Each page gets its own blob layout, picked from its path. On arrival the wash animates
// from wherever the last page's blobs were, captured just before Turbo swaps the page.
export default class extends Controller {
  connect() {
    const seed = [ ...location.pathname ].reduce((hash, char) => (hash * 31 + char.charCodeAt(0)) >>> 0, 7)
    const pick = (shift, min, max) => min + ((seed >>> shift) % (max - min + 1))
    this.element.style.setProperty("--wash-a-x", `${pick(0, -220, -60)}px`)
    this.element.style.setProperty("--wash-a-y", `${pick(5, -200, -140)}px`)
    this.element.style.setProperty("--wash-b-x", `${pick(10, 30, 62)}%`)
    this.element.style.setProperty("--wash-b-y", `${pick(15, -210, -150)}px`)

    const next = this.read()
    if (previous && this.element.animate && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.animate([ previous, next ], DRIFT)
    }
    previous = next

    this.capture = () => { previous = this.read() }
    document.addEventListener("turbo:before-render", this.capture)
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.capture)
  }

  // Mid-drift this is the in-between value, so a quick second click continues smoothly.
  read() {
    const style = getComputedStyle(this.element)
    return Object.fromEntries(PROPERTIES.map((name) => [ name, style.getPropertyValue(name).trim() ]))
  }
}
