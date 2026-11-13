import { Controller } from "@hotwired/stimulus"

// Landing on a just-claimed row keeps the context above it: the Sign-up heading when the row is in the first group,
// otherwise its group label, each 24px from the top (the smallest gap above them, so nothing half-shows), as long as the whole row still fits on screen.
export default class extends Controller {
  connect() {
    if (location.hash !== `#${this.element.id}`) return
    this.land = this.land.bind(this)
    this.land()
    // The banner and fonts can still shift the page; the browser's own fragment scroll honors the same margin.
    window.addEventListener("load", this.land, { once: true })
  }

  disconnect() {
    window.removeEventListener("load", this.land)
  }

  land() {
    const row = this.element
    const list = row.closest("ul")
    const section = row.closest("section")
    const anchors = [ list === section.querySelector("ul") && section.querySelector("h2"), list.previousElementSibling ].filter(Boolean)
    const room = window.innerHeight - row.offsetHeight - 16
    const margin = anchors.map((anchor) => row.getBoundingClientRect().top - anchor.getBoundingClientRect().top + 24).find((offset) => offset <= room)
    row.style.scrollMarginTop = `${margin ?? 24}px`
    row.scrollIntoView({ block: "start" })
    row.focus({ preventScroll: true })
  }
}
