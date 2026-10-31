import { Controller } from "@hotwired/stimulus"

// Outlives frame swaps so each re-rendered preview can compare against the last one.
const previousRows = new Map()

export default class extends Controller {
  static values = { key: String }

  connect() {
    const rows = [...this.element.querySelectorAll(".meal-slot")]
    const current = new Map(rows.map(row => [row.id, summaryText(row)]))
    const previous = previousRows.get(this.keyValue)
    if (previous) {
      rows.filter(row => previous.get(row.id) !== current.get(row.id))
        .forEach(row => row.classList.add("meal-slot-changed"))
    }
    previousRows.set(this.keyValue, current)
  }
}

function summaryText(row) {
  return row.querySelector(".meal-slot-summary > div")?.textContent.replace(/\s+/g, " ").trim()
}
