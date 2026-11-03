// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"

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
