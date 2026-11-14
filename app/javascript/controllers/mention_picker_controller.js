import { Controller } from "@hotwired/stimulus"
import { toast } from "ding"

// An "@" at the start of a word, then up to 40 characters of name, ending at the caret.
const QUERY_PATTERN = /(?:^|\s)@([^\s@\uFFFC][^@\n\uFFFC]{0,39})?$/

export default class extends Controller {
  static targets = ["editor", "results"]
  static values = { url: String }

  connect() {
    // Capture phase, so Enter and the arrows reach the menu before Trix inserts a line or moves the caret.
    this.navigate = this.navigate.bind(this)
    this.element.addEventListener("keydown", this.navigate, true)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.navigate, true)
    this.abortController?.abort()
  }

  async search() {
    const match = this.currentQuery()
    if (!match) {
      this.clearResults()
      return
    }

    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", match.query)
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (!response.ok) throw new Error(`Mention search failed with ${response.status}`)

      const { people } = await response.json()
      this.renderResults(people)
    } catch (error) {
      if (error.name !== "AbortError") {
        this.clearResults()
        toast.error("People search couldn’t load. Try again.")
      }
    }
  }

  // The "@name" being typed just before a collapsed caret, with where it starts.
  currentQuery() {
    const editor = this.editorTarget.editor
    const [start, end] = editor.getSelectedRange()
    if (start !== end) return null

    const before = editor.getDocument().toString().slice(0, end)
    const found = before.match(QUERY_PATTERN)
    if (!found) return null

    const query = found[1] || ""
    return { query: query.trim(), from: end - query.length - 1, to: end }
  }

  navigate(event) {
    if (this.resultsTarget.hidden) return

    const options = this.options
    if (event.key === "Escape") {
      this.clearResults()
    } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (options.length === 0) return
      const step = event.key === "ArrowDown" ? 1 : -1
      this.activate((this.activeIndex + step + options.length) % options.length)
    } else if ((event.key === "Enter" || event.key === "Tab") && options[this.activeIndex]) {
      this.choose(options[this.activeIndex])
    } else {
      return
    }
    event.preventDefault()
    event.stopPropagation()
  }

  insert(event) {
    this.choose(event.currentTarget)
  }

  choose(option) {
    const editor = this.editorTarget.editor
    const { sgid, content } = option.dataset
    const match = this.currentQuery()
    if (!match) return this.clearResults()

    editor.setSelectedRange([match.from, match.to])
    // trix is pinned as a UMD build, which sets window.Trix instead of exporting it.
    editor.insertAttachment(new window.Trix.Attachment({ sgid, content }))
    editor.insertString(" ")
    this.editorTarget.focus()
    this.clearResults()
  }

  renderResults(people) {
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = false
    this.editorTarget.setAttribute("aria-expanded", "true")
    this.editorTarget.setAttribute("aria-controls", this.resultsTarget.id)

    if (people.length === 0) {
      const message = document.createElement("p")
      message.className = "px-2 py-1 text-meta text-ink-2"
      message.textContent = "No matching People"
      this.resultsTarget.append(message)
      return
    }

    people.forEach((person, index) => {
      const option = document.createElement("div")
      option.id = `${this.resultsTarget.id}_${person.id}`
      option.setAttribute("role", "option")
      option.className = "flex w-full cursor-pointer items-center gap-2 rounded-control px-2 py-2 text-left text-meta font-medium text-ink hover:bg-hairline aria-selected:bg-hairline"
      const avatar = document.createElement("span")
      avatar.className = `avatar avatar-person avatar-sm avatar-hue-${person.hue}`
      avatar.setAttribute("aria-hidden", "true")
      avatar.textContent = person.initials
      option.append(avatar, person.name)
      option.dataset.sgid = person.sgid
      option.dataset.content = person.content
      // mousedown, so the editor keeps its caret instead of blurring first.
      option.dataset.action = "mousedown->mention-picker#insert:prevent"
      this.resultsTarget.append(option)
      if (index === 0) this.activate(0)
    })
  }

  activate(index) {
    this.activeIndex = index
    this.options.forEach((option, i) => option.setAttribute("aria-selected", String(i === index)))
    this.editorTarget.setAttribute("aria-activedescendant", this.options[index].id)
  }

  get options() {
    return [...this.resultsTarget.querySelectorAll("[role=option]")]
  }

  clearResults() {
    this.abortController?.abort()
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = true
    this.activeIndex = 0
    this.editorTarget.setAttribute("aria-expanded", "false")
    this.editorTarget.removeAttribute("aria-activedescendant")
  }
}
