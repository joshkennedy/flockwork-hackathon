import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  pick(event) {
    const choice = event.target.value
    if (choice === "system") {
      document.cookie = "appearance=; path=/; max-age=0; samesite=lax"
      document.documentElement.toggleAttribute("data-dark", matchMedia("(prefers-color-scheme: dark)").matches)
    } else {
      document.cookie = `appearance=${choice}; path=/; max-age=31536000; samesite=lax`
      document.documentElement.toggleAttribute("data-dark", choice === "dark")
    }
  }
}
