// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"

// data-turbo-confirm opens the layout's styled dialog; its confirm button repeats the label of the button pressed.
Turbo.config.forms.confirm = (message, _form, submitter) => {
  const dialog = document.getElementById("confirm-dialog")
  if (!dialog) return Promise.resolve(window.confirm(message))

  dialog.querySelector("#confirm-dialog-message").textContent = message
  dialog.querySelector("[data-confirm-label]").textContent = submitter?.textContent.trim() || "Confirm"
  dialog.returnValue = ""
  dialog.showModal()
  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
  })
}

// Popover menus are plain <details>; close them on an outside click or Escape like a real menu.
const closePopovers = (keep) => {
  document.querySelectorAll("details[open]:has(> .popover-in)").forEach((menu) => {
    if (!menu.contains(keep)) menu.open = false
  })
}
document.addEventListener("click", (event) => closePopovers(event.target))
document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return
  const menu = event.target.closest?.("details[open]:has(> .popover-in)")
  closePopovers(null)
  menu?.querySelector("summary")?.focus()
})
