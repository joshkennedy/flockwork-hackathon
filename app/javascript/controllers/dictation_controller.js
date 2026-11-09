import { Controller } from "@hotwired/stimulus"
import { toast } from "ding"

export default class extends Controller {
  static targets = [ "field", "button", "listeningLabel" ]

  connect() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) return

    this.SpeechRecognition = SpeechRecognition
    this.buttonTarget.hidden = false
    this.committedText = this.fieldTarget.value
    // A morph refresh would re-hide the button, because the server renders it hidden for browsers without speech.
    this.keepButton = (event) => { if (event.target === this.buttonTarget && event.detail.attributeName === "hidden") event.preventDefault() }
    this.element.addEventListener("turbo:before-morph-attribute", this.keepButton)
  }

  disconnect() {
    if (this.keepButton) this.element.removeEventListener("turbo:before-morph-attribute", this.keepButton)
  }

  toggle(event) {
    event.preventDefault()
    if (this.recognition) {
      this.recognition.stop()
      return
    }

    this.startRecognition()
  }

  startRecognition() {
    this.committedText = this.fieldTarget.value
    this.recognition = new this.SpeechRecognition()
    this.recognition.lang = document.documentElement.lang || "en-US"
    this.recognition.interimResults = true

    this.recognition.onresult = (event) => {
      let interimTranscript = ""
      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const result = event.results[index]
        const transcript = result[0].transcript
        if (result.isFinal) {
          this.committedText = this.appendTranscript(this.committedText, transcript)
        } else {
          interimTranscript += transcript
        }
      }
      this.fieldTarget.value = this.appendTranscript(this.committedText, interimTranscript)
    }

    this.recognition.onend = () => this.finishListening()
    this.recognition.onerror = (event) => {
      this.finishListening()
      toast.error(this.errorMessage(event.error))
    }

    this.setListening(true)
    this.recognition.start()
  }

  finishListening() {
    this.recognition = null
    this.committedText = this.fieldTarget.value
    this.setListening(false)
  }

  setListening(listening) {
    this.buttonTarget.setAttribute("aria-pressed", listening ? "true" : "false")
    this.buttonTarget.setAttribute("aria-label", listening ? "Stop dictating" : "Dictate")
    this.buttonTarget.classList.toggle("ring-2", listening)
    this.buttonTarget.classList.toggle("ring-red-600", listening)
    this.listeningLabelTarget.hidden = !listening
  }

  appendTranscript(existing, transcript) {
    const chunk = transcript.trim()
    if (chunk.length === 0) return existing
    if (existing.length === 0) return chunk
    return `${existing} ${chunk}`
  }

  errorMessage(error) {
    if (error === "not-allowed" || error === "service-not-allowed") return "Microphone access was denied. You can keep typing."
    if (error === "no-speech") return "No speech was heard. Try dictating again."
    if (error === "network") return "Dictation lost its connection. Try again."
    return "Dictation stopped. You can keep typing."
  }

}
