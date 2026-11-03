import { Controller } from "@hotwired/stimulus"

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

// Where the server crop (Project#banner_crop) sits along one axis: the crop window is clamped inside the photo,
// so object-position uses the same share of the overflow and the live banner matches the saved crop.
const share = (focus, size, window) => (window >= size ? 0.5 : clamp((focus * size - window / 2) / (size - window), 0, 1))

// Reposition mode works on the real banner. The full-resolution photo covers the frame, and the focal point drives
// its object-position, so the editor sees the crop that will be saved. Drags follow the photo under the pointer.
export default class extends Controller {
  static targets = [ "layer", "view", "edit", "touchEdit", "repositionButton", "x", "y", "ratio", "altButton", "altPopover", "altField" ]
  static values = { width: Number, height: Number }

  connect() {
    this.repositioning = false
    this.aspect = 3
    if (this.hasXTarget) {
      this.x = parseFloat(this.xTarget.value)
      this.y = parseFloat(this.yTarget.value)
    }
  }

  reposition() {
    this.saved = [ this.x, this.y ]
    // Start on the crop the page shows at this width: 2:1 on phones, 3:1 on desktop.
    this.aspect = window.matchMedia("(max-width: 639px)").matches ? 2 : 3
    this.repositioning = true
    this.element.setAttribute("data-repositioning", "")
    this.viewTarget.hidden = true
    this.touchEditTarget.hidden = true
    this.editTarget.hidden = false
    this.layerTarget.hidden = false
    this.showAspect()
    this.render()
    this.layerTarget.focus()
  }

  crop(event) {
    this.aspect = Number(event.currentTarget.dataset.ratio)
    this.showAspect()
    this.render()
  }

  cancel() {
    if (!this.repositioning) return

    ;[ this.x, this.y ] = this.saved
    this.exit()
    this.repositionButtonTarget.focus()
  }

  key(event) {
    if (!this.repositioning) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
      return
    }

    const step = 0.02
    const moves = { ArrowLeft: [ -step, 0 ], ArrowRight: [ step, 0 ], ArrowUp: [ 0, -step ], ArrowDown: [ 0, step ] }[event.key]
    if (!moves || event.target !== this.layerTarget) return

    event.preventDefault()
    this.set(this.x + moves[0], this.y + moves[1])
  }

  start(event) {
    if (!this.repositioning) return

    this.layerTarget.setPointerCapture(event.pointerId)
    this.drag = { clientX: event.clientX, clientY: event.clientY, focusX: this.x, focusY: this.y, ...this.renderedSize() }
  }

  move(event) {
    if (!this.drag) return

    const { clientX, clientY, focusX, focusY, width, height } = this.drag
    this.set(focusX - (event.clientX - clientX) / width, focusY - (event.clientY - clientY) / height)
  }

  stop() {
    this.drag = null
  }

  toggleToolbar() {
    this.element.toggleAttribute("data-open")
  }

  // Hides the touch toolbar once focus leaves the banner.
  collapse(event) {
    if (!this.element.contains(event.relatedTarget)) this.element.removeAttribute("data-open")
  }

  clearAlt() {
    this.altFieldTarget.value = ""
    this.altFieldTarget.form.requestSubmit()
  }

  // The popover opens under its button, right-aligned, and takes focus for typing.
  positionAlt() {
    if (!this.altPopoverTarget.matches(":popover-open")) return

    const button = this.altButtonTarget.getBoundingClientRect()
    Object.assign(this.altPopoverTarget.style, { inset: "auto", top: `${button.bottom + 8}px`, right: `${window.innerWidth - button.right}px` })
    this.altFieldTarget.focus()
  }

  exit() {
    this.repositioning = false
    this.drag = null
    this.element.removeAttribute("data-repositioning")
    this.viewTarget.hidden = false
    this.touchEditTarget.hidden = false
    this.editTarget.hidden = true
    this.layerTarget.hidden = true
    this.render()
  }

  showAspect() {
    this.element.style.aspectRatio = `${this.aspect} / 1`
    this.ratioTargets.forEach((button) => button.setAttribute("aria-pressed", String(Number(button.dataset.ratio) === this.aspect)))
  }

  set(x, y) {
    this.x = clamp(x, 0, 1)
    this.y = clamp(y, 0, 1)
    this.render()
  }

  render() {
    const [ px, py ] = this.widthValue / this.heightValue > this.aspect
      ? [ share(this.x, this.widthValue, this.heightValue * this.aspect), 0.5 ]
      : [ 0.5, share(this.y, this.heightValue, this.widthValue / this.aspect) ]
    this.layerTarget.querySelector("img").style.objectPosition = `${px * 100}% ${py * 100}%`
    this.xTarget.value = this.x.toFixed(3)
    this.yTarget.value = this.y.toFixed(3)
  }

  // The photo's size as the cover fill draws it, in CSS pixels, so a drag of one pixel moves the focus by 1/size.
  renderedSize() {
    const box = this.layerTarget.getBoundingClientRect()
    const scale = Math.max(box.width / this.widthValue, box.height / this.heightValue)
    return { width: this.widthValue * scale, height: this.heightValue * scale }
  }
}
