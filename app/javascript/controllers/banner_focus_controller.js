import { Controller } from "@hotwired/stimulus"

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

// The focal point is a 0 to 1 position on the photo. Previews use the same crop math as the server
// (Project#banner_crop), so what the editor sees is what the page shows.
export default class extends Controller {
  static targets = [ "picker", "marker", "x", "y", "preview" ]

  connect() {
    this.x = parseFloat(this.xTarget.value)
    this.y = parseFloat(this.yTarget.value)
    this.previewTargets.forEach((box) => this.imageIn(box).addEventListener("load", () => this.layout()))
    this.resize = () => this.layout()
    window.addEventListener("resize", this.resize)
    this.render()
  }

  disconnect() {
    window.removeEventListener("resize", this.resize)
  }

  start(event) {
    this.dragging = true
    this.pickerTarget.setPointerCapture(event.pointerId)
    this.moveTo(event)
  }

  move(event) {
    if (this.dragging) this.moveTo(event)
  }

  stop() {
    this.dragging = false
  }

  key(event) {
    const step = 0.05
    const moves = { ArrowLeft: [ -step, 0 ], ArrowRight: [ step, 0 ], ArrowUp: [ 0, -step ], ArrowDown: [ 0, step ] }[event.key]
    if (!moves) return

    event.preventDefault()
    this.set(this.x + moves[0], this.y + moves[1])
  }

  center() {
    this.set(0.5, 0.5)
  }

  moveTo(event) {
    const box = this.pickerTarget.getBoundingClientRect()
    this.set((event.clientX - box.left) / box.width, (event.clientY - box.top) / box.height)
  }

  set(x, y) {
    this.x = clamp(x, 0, 1)
    this.y = clamp(y, 0, 1)
    this.render()
  }

  render() {
    this.xTarget.value = this.x.toFixed(3)
    this.yTarget.value = this.y.toFixed(3)
    this.markerTarget.style.left = `${this.x * 100}%`
    this.markerTarget.style.top = `${this.y * 100}%`
    this.layout()
  }

  imageIn(box) {
    return box.querySelector("img")
  }

  layout() {
    this.previewTargets.forEach((box) => {
      const img = this.imageIn(box)
      if (!img.naturalWidth) return

      const boxWidth = box.clientWidth
      const boxHeight = box.clientHeight
      const scale = Math.max(boxWidth / img.naturalWidth, boxHeight / img.naturalHeight)
      const width = img.naturalWidth * scale
      const height = img.naturalHeight * scale
      const left = clamp(this.x * width - boxWidth / 2, 0, width - boxWidth)
      const top = clamp(this.y * height - boxHeight / 2, 0, height - boxHeight)
      Object.assign(img.style, { width: `${width}px`, height: `${height}px`, left: `${-left}px`, top: `${-top}px` })
    })
  }
}
