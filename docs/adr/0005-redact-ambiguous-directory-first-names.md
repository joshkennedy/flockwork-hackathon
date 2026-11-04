# Redact ambiguous directory first names

Status: accepted, 2026-11-04.

The Planner keeps case-insensitive redaction of directory full names and first names, including Grace, Faith, and Hope. A matching word is redacted even when it could describe a church concept rather than a person. Leading titles and articles are not first names. Matches use whole words, so words such as graceful and hopeful remain unchanged.

This follows ADR 0002. Names can appear alone in notes, descriptions, and other Planner context. Requiring a surname or limiting redaction to selected fields could send those names to a third-party model. We accept reduced clarity in ambiguous phrases rather than weaken that privacy boundary.

This decision preserves existing behavior. It does not claim that directory-name redaction detects every possible personal detail.
