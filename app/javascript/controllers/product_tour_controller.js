import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "screen"]

  connect() {
    this.show(this.buttonTargets[0].dataset.screen)
  }

  select(event) {
    this.show(event.currentTarget.dataset.screen)
  }

  show(name) {
    this.buttonTargets.forEach(button => button.setAttribute("aria-pressed", button.dataset.screen === name))
    this.screenTargets.forEach(screen => { screen.hidden = screen.dataset.screen !== name })
  }
}
