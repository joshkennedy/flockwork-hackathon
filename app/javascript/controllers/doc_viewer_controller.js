import { Controller } from "@hotwired/stimulus"
import * as pdfjs from "pdfjs-dist"

// Renders a PDF onto canvases. Bytes are fetched from the authenticated download route
// and parsed in pdf.js's own worker; the browser never renders them inline.
export default class extends Controller {
  static targets = ["pages", "current", "total", "zoom", "status"]
  static values = { url: String, worker: String, assets: String, scale: { type: Number, default: 1 } }

  async connect() {
    this.page = 1
    pdfjs.GlobalWorkerOptions.workerSrc = this.workerValue
    try {
      const response = await fetch(this.urlValue, { credentials: "same-origin" })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.arrayBuffer()
      this.pdf = await pdfjs.getDocument({
        data,
        isEvalSupported: false,
        enableScripting: false,
        wasmUrl: `${this.assetsValue}/wasm/`,
        standardFontDataUrl: `${this.assetsValue}/standard_fonts/`
      }).promise
      this.totalTarget.textContent = this.pdf.numPages
      this.statusTarget.hidden = true
      await this.render()
    } catch {
      this.statusTarget.textContent = "This PDF can't be shown here. Use Download to open it."
    }
  }

  disconnect() {
    this.pdf?.destroy()
  }

  next() { this.goTo(this.page + 1) }
  previous() { this.goTo(this.page - 1) }

  zoomIn() { this.zoomTo(this.scaleValue + 0.25) }
  zoomOut() { this.zoomTo(this.scaleValue - 0.25) }

  goTo(number) {
    if (!this.pdf || number < 1 || number > this.pdf.numPages) return
    this.page = number
    this.currentTarget.textContent = number
    this.pagesTarget.children[number - 1]?.scrollIntoView({ block: "nearest" })
  }

  zoomTo(scale) {
    if (!this.pdf) return
    this.scaleValue = Math.min(3, Math.max(0.5, scale))
    this.zoomTarget.textContent = Math.round(this.scaleValue * 100)
    this.render()
  }

  async render() {
    const token = (this.renderToken = (this.renderToken || 0) + 1)
    for (let number = 1; number <= this.pdf.numPages; number++) {
      const page = await this.pdf.getPage(number)
      if (token !== this.renderToken) return
      const viewport = page.getViewport({ scale: this.scaleValue * (window.devicePixelRatio || 1) })
      const canvas = document.createElement("canvas")
      canvas.width = viewport.width
      canvas.height = viewport.height
      canvas.style.width = `${viewport.width / (window.devicePixelRatio || 1)}px`
      canvas.className = "mx-auto mb-3 block max-w-none bg-panel shadow-sm"
      canvas.setAttribute("aria-label", `Page ${number}`)
      await page.render({ canvas, viewport }).promise
      if (token !== this.renderToken) return
      if (number === 1) this.pagesTarget.replaceChildren(canvas)
      else this.pagesTarget.append(canvas)
    }
  }
}
