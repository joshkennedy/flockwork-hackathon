import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "query", "results"]
  static values = { url: String }

  disconnect() {
    this.abortController?.abort()
  }

  async search() {
    const query = this.queryTarget.value.trim()

    if (query.length === 0) {
      this.clearResults()
      return
    }

    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (!response.ok) throw new Error(`Mention search failed with ${response.status}`)

      const { people } = await response.json()
      this.renderResults(people)
    } catch (error) {
      if (error.name !== "AbortError") this.renderResults([])
    }
  }

  insert(event) {
    const { id, name } = event.currentTarget.dataset
    this.editorTarget.editor.insertString(`@[${name.replace(/[\])\r\n]+/g, " ").trim()}](person:${id}) `)
    this.editorTarget.focus()
    this.queryTarget.value = ""
    this.clearResults()
  }

  renderResults(people) {
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = false

    if (people.length === 0) {
      const message = document.createElement("p")
      message.className = "px-2 py-1 text-meta text-ink-2"
      message.textContent = "No matching People"
      this.resultsTarget.append(message)
      return
    }

    people.forEach((person) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "flex w-full items-center gap-2 rounded-control px-2 py-2 text-left text-meta font-medium text-ink hover:bg-hairline"
      const avatar = document.createElement("span")
      avatar.className = `avatar avatar-person avatar-sm avatar-hue-${person.hue}`
      avatar.setAttribute("aria-hidden", "true")
      avatar.textContent = person.initials
      button.append(avatar, person.name)
      button.dataset.id = person.id
      button.dataset.name = person.name
      button.dataset.action = "click->mention-picker#insert"
      this.resultsTarget.append(button)
    })
  }

  clearResults() {
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = true
  }
}
