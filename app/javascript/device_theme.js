// Plain script (not a module) so it runs before first paint; the CSP forbids the inline form.
{
  const darkQuery = matchMedia("(prefers-color-scheme: dark)")
  const followDevice = () => document.documentElement.toggleAttribute("data-dark", darkQuery.matches)
  followDevice()
  darkQuery.addEventListener("change", () => { if (!document.cookie.includes("appearance=")) followDevice() })
}
