---
# gstack: design-md-format=spec
name: Flockwork
description: Warm Studio. Premium but approachable, respectable yet casual; Basecamp's warmth with the polish of Linear and ElevenLabs. Calm flat panels, tangible controls with real depth.
colors:
  frame: "#F3F2EF"
  page: "#FAFAF8"
  panel: "#FFFFFF"
  border: "#E6E4E0"
  control-border: "#939089"
  border-strong: "#B0ADA7"
  hairline: "#EFEEEB"
  ink: "#141413"
  on-ink: "#FFFFFF"
  ink-hover: "#30302D"
  ink-2: "#5F5E5A"
  ink-3: "#9A9893"
  sunlit: "#F5B000"
  sunlit-soft: "#FFF4D6"
  success: "#1F9D55"
  danger: "#D93D2B"
  danger-soft: "#FFF3F0"
  ghost-fill: "#FAF9F7"
  ghost-border: "#D6D3CE"
  nav-active: "#E6E4DF"
  tool-tasks: "#3B82F6"
  tool-schedule: "#0EA5A4"
  tool-signup: "#F5B000"
  tool-budget: "#1F9D55"
  tool-messages: "#E8590C"
  tool-docs: "#64748B"
  tool-list: "#A16207"
typography:
  wordmark:
    fontFamily: Mattone
    fontWeight: 700
    fontSize: 18px
    lineHeight: 24px
    letterSpacing: -0.01em
  display:
    fontFamily: Mattone
    fontWeight: 400
    fontSize: 30px
    lineHeight: 36px
    letterSpacing: -0.01em
  display-phone:
    fontFamily: Mattone
    fontWeight: 400
    fontSize: 24px
    lineHeight: 30px
    letterSpacing: -0.01em
  heading:
    fontFamily: Mona Sans
    fontWeight: 600
    fontSize: 15px
    lineHeight: 20px
  body:
    fontFamily: Mona Sans
    fontWeight: 450
    fontSize: 14px
    lineHeight: 21px
  body-phone:
    fontFamily: Mona Sans
    fontWeight: 450
    fontSize: 16px
    lineHeight: 24px
  meta:
    fontFamily: Mona Sans
    fontWeight: 450
    fontSize: 13px
    lineHeight: 18px
  stat:
    fontFamily: Mona Sans
    fontWeight: 600
    fontSize: 20px
    lineHeight: 24px
  label:
    fontFamily: Mona Sans
    fontWeight: 500
    fontSize: 12px
    lineHeight: 16px
  button:
    fontFamily: Mona Sans
    fontWeight: 500
    fontSize: 13px
    lineHeight: 16px
rounded:
  badge: 6px
  control: 12px
  nav: 12px
  tile: 16px
  panel: 20px
  device: 28px
  sheet: 28px
  pill: 9999px
spacing:
  1: 4px
  2: 8px
  3: 12px
  4: 16px
  5: 20px
  6: 24px
  7: 28px
  10: 40px
  control-h: 36px
  control-h-sm: 32px
  input-h: 36px
  input-h-phone: 44px
  answer-h: 48px
  phone-action-h: 48px
  page-w: 1360px
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-ink}"
    rounded: "{rounded.pill}"
    height: "{spacing.control-h}"
    shadow: "inset 0 1px 0 rgba(255,255,255,.14), 0 1px 1px rgba(20,20,19,.12), 0 2px 6px rgba(20,20,19,.12)"
  button-primary-hover:
    backgroundColor: "{colors.ink-hover}"
  button-primary-active:
    transform: translateY(1px)
    shadow: "inset 0 2px 3px rgba(0,0,0,.3), 0 1px 1px rgba(20,20,19,.08)"
  button-secondary:
    backgroundColor: "{colors.panel}"
    borderColor: "{colors.border}"
    rounded: "{rounded.pill}"
    shadow: "0 1px 2px rgba(20,20,19,.06), inset 0 -1px 0 rgba(20,20,19,.04)"
  button-text-danger:
    textColor: "{colors.danger}"
  input:
    backgroundColor: "{colors.panel}"
    borderColor: "{colors.control-border}"
    rounded: "{rounded.control}"
    height: "{spacing.input-h}"
  tile-raised:
    backgroundColor: "{colors.panel}"
    borderColor: "{colors.border}"
    rounded: "{rounded.tile}"
    shadow: "0 1px 2px rgba(20,20,19,.05), 0 4px 12px rgba(20,20,19,.04)"
  tile-ghost:
    backgroundColor: "{colors.ghost-fill}"
    borderColor: "{colors.ghost-border}"
    borderStyle: dashed
    textColor: "{colors.ink-2}"
    rounded: "{rounded.tile}"
  panel:
    backgroundColor: "{colors.panel}"
    borderColor: "{colors.border}"
    rounded: "{rounded.panel}"
  popover:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.panel}"
    shadow: "0 8px 24px rgba(20,20,19,.12), 0 2px 6px rgba(20,20,19,.06)"
  badge-need:
    backgroundColor: "{colors.sunlit-soft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.badge}"
  nav-item-active:
    backgroundColor: "{colors.nav-active}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
  person-pill:
    backgroundColor: "{colors.hairline}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    height: 24px
---

# Flockwork

## Overview

**Creative North Star:** "Care, not software," expressed as premium but approachable. Flockwork should feel as considered as Linear or ElevenLabs and as warm and plain-spoken as Basecamp: respectable enough for church leadership, casual enough for a volunteer opening a text link.
**Product context:** "Basecamp for churches." Leaders and Admins plan and oversee on desktop; Volunteers claim and check off work on phones. References studied on Mobbin: Linear project overview, ElevenLabs home, Basecamp project home, plus AI question-card flows, slot pickers and workload views (as patterns to avoid for people).
**Mode per surface:** Planner, Project page, Team: Operate (desktop-first). Home for Volunteers, sign-up, Invitations: Operate (phone-first). Oversight: Read. Public link: Persuade, lightly.
**Reference preview:** `~/.gstack/projects/joshkennedy-flockwork/designs/design-system-20261030/preview-warm-studio-v2.html` (approved 2026-10-30).
**Key characteristics:**
- A white sheet on the warm `frame` canvas, with the header wash across its top. A floating, fully rounded top bar and the sheet share one centered 1360px column.
- Near-monochrome ink; a single gold accent (sunlit) reserved for open needs, the kept check and celebration.
- Mattone, a heavy wide display face, only for the wordmark and page-level headlines; Mona Sans for everything else.
- Interactive things are tangible: raised tiles and buttons with layered soft shadows that press in. Panels and lists stay flat.
- AI Suggestions are ghost tiles (dashed, muted). A Leader's Keep turns them solid with a gold check. People are always shown by name, never scored.

## Colors

**Strategy:** Restrained. Ink carries text and the one primary action per view. Sunlit appears only as a fill (`sunlit-soft` behind "1 spot left" and team notes) or as an icon (the kept check), never as text on white. Danger is for destructive text actions only. Tool colors appear only on Tool icons, the way Linear colors status icons.
**Light or dark:** Both, chosen per device on Profile (Light, Dark, Match device; kept in an `appearance` cookie, default follows the OS). Dark sets `data-dark` on `<html>` and swaps every token for warm near-blacks: frame #141413, page #191918, panel #1D1D1B, border #2E2D2A, ink #F2F1ED, ink-2 #AAA8A2, sunlit-soft #3A2D0E. Ink stays the primary action, so primary buttons turn light with dark text. Shadows deepen and gain a faint top highlight so raised tiles still read as raised. The default mark brightens to sunlit in dark; a church's own color is set inline and stays as picked. Disabled buttons sit on `nav-active` in dark, since `frame` is darker than `panel` there. Both layouts set `theme-color` (frame in light, #141413 in dark) so phone browser bars match.
Contrast (measured in the preview): `ink-2` on `panel` 6.49:1, `ink-2` on `frame` 5.80:1. `ink-3` is only for non-essential hints (keyboard numbers, breadcrumb separators), never body text.

| Token | Light | Dark | Purpose |
| --- | --- | --- | --- |
| `control-border` | `#939089` | `#6B6964` | Input and control boundaries, 3:1 on panel |

**Mark (Formation):** three round-capped chevrons flying in a V on a 24-unit grid; the lead bird is 1.15x the size of the two `ink` followers (stroke 2.8, lead 3.22). The lead is `mark` (#D69000, a deeper sunlit: plain sunlit is only 1.8:1 on `page` and disappears); on dark it goes back to bright `sunlit`. The lockup is `layouts/_wordmark`, an inline SVG set 15px tall beside the wordmark with an 8px gap so its strokes match Mattone Bold; the lead reads `--color-mark`, which each layout sets on `<body>` from the church's `mark_color`. An Admin picks it on Settings from seven presets (Deep sunlit, Copper, Clay, Berry, Teal, Forest, Cobalt) or a custom hex. The mark color only recolors the mark: in-app `sunlit` keeps its meaning for open needs and the kept check. The favicon is served by `IconsController` at `/icon.svg?c=<hex>` (followers white in dark browser chrome; the default lead also brightens to sunlit there). `public/icon.png` is the app icon: the mark on a full-bleed `page` tile, so iOS never fills the corners black. Never add a fourth bird or set the mark without its colored lead.

## Typography

**Mattone** (Collletttivo, designed by Nunzio Mazzaferro, SIL OFL 1.1, self-hosted from `github.com/collletttivo/mattone` woff2, Regular/Bold/Black) is the signature: the "Flockwork" wordmark (Bold 18px) and page-level headlines (Regular 30/36 desktop, 24/30 phone): Project names on their page and the Oversight headline. The Planner question is not a page headline: it uses the ordinary heading scale in Mona Sans. It is wide and heavy, so it never sets body, buttons, labels, numbers, or anything below page level.
**Mona Sans** (GitHub, Google Fonts, variable weight and width) sets all UI and body at normal width: headings 600 15/20, body 450 14/21 (16/24 on phones), meta 13/18 in `ink-2`, labels 500 12/16, primary and secondary buttons 600 14/16 (small 13/16, phone primary 600 15), text buttons 500 13/16.
Numbers: Mona Sans's tabular figures carry a dotted zero, so use `tabular-nums` only in aligned numeric columns (Budget totals, tables). Times, dates and counts in running text use default proportional figures with a plain zero.
Sentence case for headings, navigation, labels, tabs, links, status chips and running copy. Every visible button label uses Title Case, including primary, secondary, text, destructive, form-submit and menu-action buttons. Icon-only buttons keep an accessible sentence-case `aria-label`. No tracked all-caps, no monospace decoration, no italic display.

## Layout

App shell, 768px and up: a `frame` canvas holding one white `panel` sheet (28px radius, hairline border) the same width as the top bar, 20px below it, with the header wash tinting its top. The top bar and the sheet share one centered `page-w` column (1360px). Phones use the same sheet inset 8px. The 56px top bar is a sticky floating pill (`pill` radius, `panel` fill, float shadow, a hairline edge in dark) 16px from the top; its wordmark lines up with the content's 40px gutter. Once the page scrolls, a frame-colored band fades in behind it so content passing under doesn't show above the pill. 48px of room sits between the bar and the first heading. The bar holds the wordmark on the left, the destinations centered, and Search, the bell (Notifications, with its unread count) and the account avatar on the right. Destinations are text pills, 40px tall, 14px semibold, always labeled, never icon-only; the current one fills with `nav-active`. Home, Projects and Get involved are the whole nav for a Volunteer. People, Oversight and Settings sit in a Manage dropdown; someone allowed only one of them (a Leader has only Oversight) gets it as a plain pill. The avatar opens the account menu (church name, Switch Church, Profile, Terms, Privacy policy, Sign Out). The bell opens Notifications as a 380px flyout (a sheet on phones): what needs you first, then the newest of the rest, eight rows at most, Mark All Read, and a link to the full page. There is no breadcrumb bar: only pages inside a Project show a breadcrumb, as one 12px `ink-2` line above the page content. Sheet padding 40px desktop, 16px phone. Major blocks separated by 40px in the signed-in app on wider screens (the `7` step is 28px everywhere else: phones, public and sign-in pages); status strips and aside panels inside the sheet take the `page` tint so they read as their own surface; groups by 20px; tiles by 8px (12px on phones). The build-as-you-go Planner is one fixed-width stage, at most 880px and centered in the panel: a 340px question column beside the preview, which takes the rest. Below 1024px the two stack, the question first. The Project name is the only display heading; the current question uses the ordinary UI heading scale. Oversight keeps its two-column scan, but each check-in candidate is one compact bordered group: Person, one reason sentence, check-in status, then the action. Phones: the page keeps the warm `frame` with the content in an inset `panel` card 8px from its edges (the wash inside the card), and the browser bar matches the frame; the top bar loses its pill and sits on the frame, holding the wordmark, Search, the bell and the account avatar; a tab bar at the bottom holds the destinations, with Manage as a tab that opens a sheet, padded for the safe area; 16px gutters; one full-width primary action per card. During planning, show the current choice with the most recently changed preview row and an explicit View all route so the work is never reduced to a count.

**Every screen answers one question.** Home opens "Hi <first name>" (no time-of-day greeting: the app runs on UTC and keeps no church time zone) and works the same for every role, top down: pending Invitations, then "Your Tasks" (open Tasks in due-date order, Done in place), then "Coming up" (your upcoming sign-up Slots). Leaders and Admins skip either section when it is empty, so their own view leads; Volunteers keep the one-line empty state. Below that the role's own view. Admins see "is the whole church covered?": a status strip of org-wide counts, then every active Project sorted by need with its Leaders and status (header wash tint `wash-admin`). Leaders see "what do my Projects need next?": one raised tile per Project they lead with the single action that unblocks it (Fill Spots, Assign Tasks, Plan It). Volunteers see their Projects, then "what's still needed?" (open spots this week on their Projects) and then "how else can I help?" (open Teams they are not on), tint `wash-volunteer`. The Projects index groups rows under Happening now, Coming up, No dates yet, Ended and Done, with When and Status columns in plain counts. A Project page stacks title and description (Plan More and a ⋯ menu on the right), a status strip (When, Covered in spots, Next open or Assigned/Next due, Team), a guidance strip (`sunlit-soft` fill, the open need in one sentence, the view's one primary action), then tabs: every enabled Tool except Recipients, Tools with content first, plus Notes, plus a Team tab that links to the Team page. Tabs switch client-side and remember the last tab per Project; every panel is server-rendered. Under the tabs the active Tool takes the wide column and a 320px side column holds Recipients with their care notes and the always-visible Sharing and ownership section. The Sign-up sheet shows This week and Next week as flat rows, with Past and Later folded away; on phones an open Slot keeps its raised tile. Add Slot is an attached split control whose menu opens Generate Multiple Slots in a modal that explains the repeated result before the form. The Team page lists Members (Leaders first, removal behind ⋯) with inviting and Invitations in a side column for those who manage the Team. Get involved opens with up to three raised Needs a hand rows, each wholly clickable. Open Project cards use clickable images and honest browse actions: "View Open Spots" when help is available, otherwise "View Project". Joining happens only after the person has seen the Project. Project rows carry a small banner thumbnail when the Project has a photo; without one the row shows nothing there (only the flush image slot on Get involved cards keeps a tool-tinted tile). Archived and Deleted lists use the same row grammar as the Projects index. The People directory is one list: quick filters on a tab bar, live search, then rows (see Directory row). A person page (Admins only) opens with a profile header: a 56px avatar, the name as the only heading in Mattone, the email and phone as `mailto:` and `tel:` links, status chips, and one secondary "Edit Details" button, which opens the edit form on its own page. Below the header come five sections, each answering one question: Serving now (Projects with role), History (the year table and past Projects), Check-ins (last check-in and "Log a Check-In"; the note only for Admins), Away dates (dates only, never the note) and Notes.

**Contextual interaction update:** Past and Later Slots use a full-width tonal disclosure bar with a plain title, a count/status line and the house plus-to-close mark. Add Slot remains an attached split control: its main action opens a right slideout over the Project, while its menu opens Generate Multiple Slots in the explained modal. Edit Slot uses the same slideout from each row's ⋯ menu; direct form URLs remain usable as fallbacks. Small forms that edit something visible on the current Project use this right-slideout pattern. Multi-item creation that needs explanation uses a centered modal.

## Elevation & Depth

Three levels only. Flat: panels, lists, team notes (border or tint, no shadow). Raised: the top bar (with a hairline edge, like the sheet), answer tiles, open Slots, kept Suggestions, highlight tiles (`0 1px 2px rgba(20,20,19,.05), 0 4px 12px rgba(20,20,19,.04)`). Floating: popovers, menus, dialogs, toasts (`0 8px 24px rgba(20,20,19,.12), 0 2px 6px rgba(20,20,19,.06)`). Buttons carry their own inner highlight and press shadow (see components). Never a zero-offset glow, never a card inside a card.

## Shapes

The floating top bar sets the shape language, and each kind of thing keeps one shape so it can be told apart at a glance. Things you press are fully round: buttons, icon buttons, nav pills, the Search trigger and the Person pill. Things you type in are 12px: inputs, selects and textareas. Things you read are softer boxes: badges and status chips 6px, rows inside menus and search 12px to 16px, tiles 16px, panels, popovers and dialogs 20px, phone device frame 28px. Person avatars are 32% rounded squares (a squircle whose ring follows the shape). Tabs and quick filters stay underlined text, never pills, so a filter is never mistaken for a destination or an action. Status chips and badges never become pills.

## Components

- **Primary button:** ink fill, fully round, white 14/600 label with 16px side padding, 36px tall (32px small with a 13px label, 48px full-width on phones), inner top highlight plus two soft shadows. Hover lightens to `ink-hover`; active presses 1px with an inset shadow; focus-visible is a 2px ink outline offset 3px with a panel-colored gap; disabled is `frame` fill with `ink-2` text and no shadow. One per view.
- **Secondary button:** fully round, white with border and a hairline bottom inset; same press behavior.
- **Text link:** a link inside running text is `.link`: `ink` text (usually `font-medium`) with a 1px underline in `border-strong`, offset 0.25em so it clears descenders, that turns `ink` on hover. Never the browser's default underline, which is thick in Mona Sans and chops around descenders, and never color alone.
- **Text button:** no chrome, 13/500 `ink-2`, a fully round hover tint, hover tints with `hairline`; danger variant in `danger` with `danger-soft` hover.
- **Planner answer tile:** raised tile 48px tall, 14px padding, radio on the left, keyboard number 1–4 in `ink-3` on the right; hover darkens the border to `border-strong`; selected shows an ink border and filled radio; pressed sinks 1px.
- **Pending Planner work:** generated work stays on the `ghost-fill` surface with a dashed `ghost-border` and one "Suggestions · not added yet" state label for the whole preview. Tool contents use compact rows rather than a card per item. Edit opens fields in place; Remove lives inside that edit area, and Undo appears after removal. There is no Keep/Edit/Drop queue. One final Add to Project action accepts every visible, non-removed item.
- **Meal setup:** one All Details form with a single large editable Project-name field, then Meal and Schedule groups. The name field replaces the displayed title and duplicate name input; it shares the approved Mattone display field with the Planner page. The Planner title saves on change, blur or Enter; an empty name restores the previous name. Omit the subtitle and repeated meal label. Use the existing `page` tone behind the Sign-up sheet; date, meal and row action share fixed columns. Ellipses open floating edit popovers with Remove at the leading edge and Cancel/primary Save at the trailing edge. Popovers stay within the viewport and preserve row heights. Structured values produce dated slots without AI. Fields save automatically, with save status at the top right opposite a visible Back to Project button. Clearing the name saves a quiet draft and keeps the meal preview visible; a name is required before Add. Keep Add below the form, sticky during long-sheet review, with explicit editing-state feedback. Back to Project and other navigation flush pending saves. Failed saves keep typed input visible and offer Retry Saving. Retain removal/Undo, conflict resolution and atomic acceptance. Do not show question cards, Continue, Finish with This, Save and Leave or the Planner privacy paragraph.
- **General Planner choices:** answer tiles retain their raised treatment and show an unmistakable selected radio and ink border. A typed answer is the selected answer too: it shows as "Your answer" above the choices, and Continue advances after the same preparation. Selecting an answer prepares the visible preview, and Continue appears as the ink primary once an answer is chosen (before that the answer tiles are the next step); Continue only advances after that preparation completes. While the Planner works, the preview shows dashed skeleton rows with the text "Building the Sign-up sheet…", and each complete item appears as its own row as it is generated (rows appear in order and never repeat). The skeleton stays until the step finishes, and Continue is enabled only after the final result replaces the streamed rows. Back, Finish with This, and Save and Leave are quiet actions. The final primary changes to Add to Project in the same organization.
- **Slot (phone):** claimed Slots are flat rows (date 14/600, "✓ Ruth Bennett" in `ink-2`); open Slots are raised tiles with date, a `badge-need` when two or more spots are open ("3 spots left"; a single open spot is said by the button alone) and a full-width primary "I Can Bring Dinner"; after claiming the tile flattens and shows "You're bringing dinner" with the sunlit check.
- **Inputs:** 36px tall, the same as a button so a field and a button share a row (44px phone), 12px radius, 14px side padding, `control-border`, placeholder in `ink-2`; the dictation mic is an icon button inside the field. Labels sit 8px above their field.
- **Code field:** a one-time code is one input, never six boxes, so paste and the phone's code autofill work. It is 44px tall at every width, with the digits in the `stat` scale (20/24, 600) and 0.3em tracking so six of them read as a code. It carries `inputmode="numeric"` and `autocomplete="one-time-code"`.
- **Public link sign-in:** three steps on the public layout, one question each, each wearing the church's mark color like the Public page. Tapping "Help with This" on a Slot carries that Slot through sign-in: every step names it in one meta line under the heading ("Wednesday, November 11 · Dinner"), and finishing claims it. "Sign in to help" has one "Email or mobile number" field, one meta line under it in `ink-2` ("Msg & data rates may apply. Reply STOP to opt out."), Send Me a Code and a quiet "Back to <Project>" link (meta 13/18, 500, `ink-2`, underlined; 44px tall on phones). A number that cannot get a text (an Admin's, one outside North America, or past the church's hourly share) is asked for email in the error. "Enter your code" says only where the code went, with the address masked ("Sent to j•••@gmail.com.", "+1 ••• ••• 4567"), with Resend Code as a secondary button and a quiet "Change email or phone" link 12px from it. "What's your name?" appears only for someone new, and only after the code; its field keeps a screen-reader label with the placeholder "First and last name", since the heading already asks, and its primary is Confirm My Spot when a Slot was tapped (Continue otherwise), with the same "Back to <Project>" link under it. An error sits above the form in `danger-soft`. Signing in lands on the Public page at the tapped Slot, already claimed, and that row is the confirmation, with no toast over the page: it scrolls to 40px from the top so its group label shows, takes focus so screen readers read it, and gets the 180ms preview-update emphasis with its kept check scaling in (instant under reduced motion); if the Slot filled meanwhile, a calm notice asks them to pick another. Once signed in the page shows "Signed in as <name>" beside the wordmark with a text Not You? that signs out and stays on the page. Tasks are Team work, so the public page lists them only to Team members, each with I'll Do It. The public Sign-up list groups upcoming Slots like the Sign-up sheet (This week, Next week, then Later folded behind the disclosure bar, open when nothing nearer exists or when it holds the helper's own spot); Past Slots are left off. Each row leads with the day and time ("Wednesday, November 11 · 6:00 PM", 600 `ink`) with the label as meta below. A signed-out row says "Help with This"; once signed in the same row carries the claim in the person's words ("I Can Bring Dinner", "I Can Help"), and a claimed row lies flat (border on the page tone, no fill, no shadow) with the sunlit check (2px stroke) and "You're bringing dinner" (or "You're signed up" for other labels), plus a text Unclaim lined up with the row's text when it wraps on phones.
- **Selects:** an input with the bar's chevron 12px from the right edge in place of the browser arrow.
- **File pickers and checkboxes:** the browser's file button wears the small secondary button; checkboxes and radios are 16px in `ink`.
- **Rich text toolbar:** grouped 36 by 32px icon buttons (40px phone) in a 12px bordered group; the active tool takes `nav-active`.
- **Button grammar:** every visible button label uses Title Case. Four kinds of action, one look each. The view's next step: ink primary, one per view, in the header or guidance strip. Add to a section: small secondary with a plus, right of the section heading, always "Add …". Do the thing (Volunteer-facing): small secondary worded as the person would say it ("I Can Bring Dinner"). Manage it: a ⋯ icon button opening a menu (Edit, Duplicate, Archive, then Delete last in `danger`). No inline Edit/Delete on rows, no bare-text section actions. List columns follow the same rule: one ⋯ menu per column header.
- **Disclosure grammar:** native disclosure triangles are hidden. A text disclosure uses a plain-language label plus the house plus mark, which turns into a close mark while open, with a quiet tonal hover. A folded group of rows uses the full-width tonal disclosure bar with its count or status on a second line. Attached action menus use an ellipsis. Actions such as comments use a compact text button with an action label ("Add Comment"), never an unstyled noun. Sections needed to understand the current screen, including Sharing and ownership, stay open rather than becoming disclosures.
- **Avatar:** a person's initials (first letter of the first and last name, one letter for a one-word name, "?" for no letters) on a 32% rounded square: 20px `sm` in meta lines, pills and stacks, 28px by default in lists, 56px `lg` on Profile and the person page. The fill is a 135-degree wash from one of ten hues in the header wash family (`avatar-hue-0` to `9`, tokens `avatar-0` to `9`) into the next hue around the wheel, using B's light and dark palettes. The hue is chosen by `Zlib.crc32` of the person's email, or of their name when there is no email, so a person keeps one color everywhere and across restarts. Ink initials clear 10.4:1 on the light wash, and `#F2F1ED` clears 7.6:1 on the dark wash, on every hue. A faint top highlight (`--shadow-avatar`) gives depth without a border. Static avatars never move; one inside a link or button lifts 1px on hover. Beside a visible name the avatar is `aria-hidden`; a bare avatar (the phone top bar) names itself with `role="img"`. Several people show as an overlapping stack of up to three plus a "+N" tile, and each avatar's ring follows the same shape in the surface behind it (2px, 1.5px in 20px stacks).
- **Person pill:** a name in running text (task and comment authors, meta lines, Slot claimers, notifications, Invitations, Home leaders). A `hairline` pill, 24px tall, with the 20px avatar flush at its left end (a 2px inset) and the name in 13/18 `ink`. No border, so it reads as a label rather than a button. Several people share one pill: the overlapping stack, then their names. A pill that links to the person gets a gentle `nav-active` hover; a static pill never changes on hover. Where the row is already the container (Team members, People, Oversight, Invitations and Recipients lists, the account menu head) the avatar sits alone beside the name instead.
- **Status chip:** a 6px badge (`status-chip`) with `hairline` fill, 12/16 `ink` label, naming a fact about a Person: Leader, Admin, "Away until Dec 1", "Can't sign in". "Not yet asked" is an open need, so it takes the `sunlit-soft` fill (`status-chip-need`). Chips never become pills and never carry a color for status; they sit beside the name, wrapping only on the person page.
- **Directory row:** the avatar, then the name as the row's link (the whole row is clickable), its status chips, and one meta line naming the Active Projects they serve on ("Serving on Kids Ministry and Greeters, and 1 more"), truncated to one line. Someone serving on none shows just the name; the Serving now filter answers the rest. Rows group under their first letter (a 13/18 600 `ink-2` label, 24px between groups) so the long list has landmarks. Contact details and historical activity stay on the Person page and never appear in the directory.
- **Quick filters:** the `tab-bar` of links across the top of a list, each with its count in plain `ink-2` (no badges). The current filter is `aria-current="page"`. Filters are query parameters, so they can be shared and combine with search; a live search form keeps the filter in a hidden field.
- **Account menu:** one popover, opened by the avatar in the top bar. From 768px it drops under the avatar; on phones the same items open as a sheet above the tab bar. Identity head (avatar, name at 13/600, church at 12/16 `ink-2`), Switch Church for someone in several Organizations, Profile, Terms, Privacy policy, a hairline, then Sign Out. Its rows are 16px rounded so they sit concentric inside the 20px panel. It is a `details` disclosure, so Enter or Space opens it and Tab moves through the items; Escape or an outside click closes it and Escape returns focus to the trigger.
- **Phone tab bar:** fixed to the bottom on `frame` with a hairline top border. It has one column per destination the Person can open (Volunteers see three). Each tab is at least 44px tall, with a 20px icon and an 11px label; the current tab is `ink` and 600. Notifications is not a tab. It is the bell in the top bar, and its count is an `ink` badge. Bottom padding follows `env(safe-area-inset-bottom)`, which needs `viewport-fit=cover` in the app's viewport meta.
- **Tool rows:** the Tasks list is the model. A task is completed by a 20px ring at the left with a 44px hit area; hovering previews the check, and a completed task becomes a sunlit disc with the check, so no "Done" button appears. The title is `heading`, with one meta line of assignee and due date. Due dates read relatively near today ("Due in 3 days", "Overdue by 2 days", "Due Apr 9" beyond eight weeks), with the exact date in the `<time>` title. Task comments use a compact labelled disclosure. Slot comments live inside the row's ⋯ menu so they do not interrupt the schedule; choosing Add Comment or View Comments opens one tonal panel directly below that Slot. Claim stays a small secondary button; Unclaim, Edit and Delete live in the row's ⋯ menu. Schedule items follow the same title-then-meta order.
- **Messages:** one plain-text composer sits above a flat chronological thread. Author, time and the ⋯ menu share one header row; replies indent without a decorative rail. Message bodies preserve newlines but have no rich-text toolbar or mention picker. Reply opens a small plain-text composer beneath its conversation. This is discussion, not chat, so messages never become bubbles or cards.
- **Header wash:** the decorative surface for pages. The avatar wash is the only other gradient. Two or three blurred radial blobs (closest-side radial gradients, 24px blur) at 9–22% alpha in tool or accent colors, plus SVG `feTurbulence` grain at 10% alpha multiplied on top, masked to fade out by 300px from the top of the panel. The tint carries meaning: `sunlit` for sign-up work and Leader views, `tool-schedule` teal for the Admin overview, `tool-messages` orange for Volunteers. Header content sits above it; anything that sits on it (the status strip) gets a 75% white fill. Never behind rows, forms, the Planner, or text that needs 4.5:1.
- **Project banner:** an optional photo above the Project header, in a `rounded-panel` frame with a `border`. It crops to 3:1 on desktop and 2:1 on phones, around a focal point that defaults to center (an AI suggestion can move it, an editor can set it). A photo too small for the crop sits whole on a blurred copy of itself and is never upscaled. With no photo, nothing sits above the Project header: editors add one from the Project's ⋯ menu (Add Banner), and the public page shows only the photo. With a photo, editors get no controls below it. Replace, Reposition, Alt text and Remove sit on the banner as a row of translucent `panel` chips with backdrop blur, shown on hover or focus (a single small edit button shows them on touch), and dropping an image on the banner replaces it with a dashed `ink` highlight. Reposition works on the real banner: the full photo fills the frame, drags with the pointer or arrow keys, and shows the Desktop 3:1 or Phone 2:1 crop it will save, with Save and Cancel (Escape) on the photo. Alt text is optional: a popover on the banner edits or clears it, and the AI still fills it in.
- **Privacy disclosures:** public Terms and Privacy pages explain storage, Planner context, xAI voice audio and browser dictation. Link them from the landing footer and account menu, never inside the Planner flow.
- **Notification list:** two regions on one page. "Needs you" is the top section, newest first, with at most one small secondary action per row: Respond (an Invitation), Mark Done (a Task), or Open. "For your information" groups the rest under their Project name (12/16 label in `ink-2`), with plain rows and Mark Read. The bell and its count show unread "Needs you" items only. Both sections use plain rules, never AI copy.
- **Notification preferences (Profile):** the Notifications tab shows a plain comparison table, one row per notification type and independent In-app, Email, and SMS checkboxes. Each checkbox has a 44px click target and a label naming both the event and channel. Any combination is allowed, including none. Existing email choices remain, in-app starts on, and SMS starts off. The SMS number and Change Phone link sit below the table with the opt-in explanation. Enabling SMS requires a phone number with its country code; errors stay beside the form. These settings apply to new notifications.
- **Away dates (Profile):** a "When you're away" section under the profile form. A single text box takes the person's own words and "Suggest Dates" proposes ranges as a ghost tile labelled "Suggested · not saved yet", with editable From, Until and Note fields and "Save These Dates". Nothing is stored until that press. With no AI, or when it cannot read the words, the same fields appear with "Add Dates" and an alert in `danger-soft`. Upcoming ranges list as "Away Mar 1 to 14" with a text Remove. The note appears only to the person who wrote it.
- **Away line (Oversight):** a plain list under the two urgent columns, each row a name with its avatar and "Away until Nov 9" (while the range is on) or "Unavailable Mar 1 to 14" in `ink-2`. It shows dates only, never the note, and a person in this list is never counted as overextended.
- **Check-in card (Oversight):** one row per person who may need a check-in, with the name and avatar, the Active Projects they serve on, and a line "Checked in Oct 28 by [person pill]" or "No check-in logged yet." The button "Log a Check-In" is a small secondary action that logs today; "Date or note" opens a date and a private note, which only Admins see. Someone checked in within 30 days leaves the list until the window passes.
- **Summary line (Oversight cards):** under each check-in card's facts, a ghost tile (dashed `ghost-border`, `ghost-fill`) labelled "Summary · from counts" with one sentence such as "Serving on 4 Active Projects since September, no check-in logged." It is written from counts and dates only, and it is generated once per person for their exact counts and cached for 30 days. Until it is ready, and with no AI, the same sentence comes from a template. It never names anyone.
- **Skills field:** the seeded skills as a two-column checkbox grid (like the Tools fieldset), then one "Other skills" text box for comma-separated tags. Used on Profile, the Person edit slideout and the Project form ("Skills needed"). Skills show as a plain meta line ("Skills · Driving, Cooking"), never as status chips.
- **Suggested for this Project (Team tab):** the first panel in the "Grow the Team" aside, for Team managers only. Up to five rows: avatar, name, the matched skills and serving load, and the same Invite form as directory search. Empty states: no Skills needed links to the Project form; no matches says "No one free lists … yet."
- **Toast:** Ding renders one toast at a time and morphs a new notice, alert or upload state into the current toast. It sits top center, below the app header on phones. Public pages have no fixed header, so there it keeps the top edge at every width; a claim there confirms on its row, never in a toast. Ding follows the app's light or dark appearance. Notices leave after 5 seconds; errors, loading states and toasts with actions stay until dismissed. Its persistent live regions announce errors assertively and other updates politely. Escape dismisses and Alt+T focuses the toast. Flash text reaches Ding as text, never HTML.
- **Confirm dialog:** every destructive action (Delete, Remove, Leave, Turn Off, Reset) carries `data-turbo-confirm`, which opens the layout's small modal instead of the browser's. One sentence says what goes and what follows ("Delete this Slot? 2 people signed up will lose their spot."), with free-text titles in curly quotes. Cancel (secondary, focused) and the pressed button's own label as the ink primary.
- **States:** empty ("Nothing here yet"), loading ("Thinking…" on the Planner), and error are designed text in the panel, not blank space. The planner error is a calm `sunlit-soft` panel: "The planner is taking a break — you can keep going by hand.", with Retry (secondary) and "Keep going by hand" (text), and it keeps every answer and preview row already given. The Planner's start offers "Build it myself" as a visible secondary action beside the kind tiles.

## Do's and Don'ts

- Do keep AI output as ghost tiles until a human keeps it.
- Do make every line of text earn its place: keep what prevents a wrong action (privacy, consequences, limits, unsaved states, how to fix an error, the next step from an empty state). Cut text that restates its heading, tab or button, or that explains how a list is sorted.
- Do use an icon only where it works alone (icon buttons, the phone tab bar, ⋯ menus, chevrons, the kept check) or stands in for something missing (a Project with no banner, a notification with no person, a row still being drafted). The mic stays on voice controls and the magnifier on Search. No other icon beside a label that already says it; a tab panel does not repeat its tab as a visible heading.
- Do show people by name with plain counts ("4 active Projects", "14 meals this year"); never bars, percentages, red flags or scores.
- Do reserve Mattone for the wordmark and page-level headlines, and depth for things you can click.
- Do keep exactly one primary (ink) button per view.
- Don't use gradients (except the header wash and the avatar wash), purple or indigo, glows, emoji, icon tiles above headings, kicker labels, pill-shaped tabs, filters, chips or badges (round is for things you press and the Person pill), avatar walls (more than the three-avatar stack), chat bubbles for the Planner, or cards inside cards.
- Don't set Mattone below 24px or on anything interactive except the approved editable Project-name field in meal setup and the Planner.

## Motion

- **Approach:** minimal-functional.
- **Easing:** enter ease-out, exit ease-in, move ease-in-out.
- **Duration:** press 100ms, hover/border/background 150ms, preview-update emphasis 180ms. Nothing longer than 300ms, with two exceptions: the header wash drifts for 1600ms (`cubic-bezier(0.45, 0, 0.25, 1)`) from the previous page's blob layout and tint to the new page's. Each page's layout comes from its path, the drift never delays content, and `prefers-reduced-motion` skips it.
- **Building state:** while a step is being prepared, the Planner loops one 1600ms opacity shimmer on the preview skeleton, the status line's pulse dot and the chosen tile's radio. It is a second exception to the 300ms rule. It stops under `prefers-reduced-motion`, and the text label carries the state without it.
- **Voice orb:** the Planner voice orb is the one amplitude-driven loop. Its rings scale with live audio, its core breathes at idle over 1600ms, and both stop under `prefers-reduced-motion` while the status text carries the state.
- **The authored moment:** a changed choice produces a short tonal emphasis on the affected preview row after the new content is already visible. Content is never hidden waiting for an entrance animation. `prefers-reduced-motion` removes transforms and makes the tonal change instant.

## Marketing pages

The landing page and every public page built from it (feature, use-case and pricing pages) follow these rules. They are what moved the landing page in the 2026-11-09 council run.

- **One measure:** content sits on `--lp-max` (1168px) with 24px gutters (16px on phones). The header, every section, photo rows and the footer share one left edge. Only the in-between intro and the close are centered.
- **Public header:** marketing pages use a sticky header, transparent over the hero at the top and page-colored with backdrop blur and a hairline below after 8px of scrolling. Without JavaScript it keeps the readable blurred surface. Auth pages keep the plain header. Current links use `aria-current="page"` and heavier ink. At 720px and up, Features opens a two-column panel on hover or keyboard focus, with registry summaries and bare tool icons, followed by All features. Features itself remains a link. Phones show the four plain links on a second row with 44px tap targets.
- **Interior hero:** features, pricing, about and contact share a quieter version of the home color field, with fine texture behind left-aligned copy. The field runs under the header and fades into the page; dark mode uses ink with low amber light. Desktop heroes start at 540px (600px with feature breadcrumbs), leaving the following section visible at 1280×800. These are minimum heights, so longer copy can grow without clipping.
- **Type:** Mattone for the h1 and h2 only (h1 `clamp(44px, 6.6vw, 84px)`, h2 28 to 48px), sentence case, ending in a period. Body copy 17 to 19px at 1.6. h3 17 to 20px, 600.
- **Labels:** buttons are Title Case; links are sentence case and never repeat a button's words in another case (the nav says "Demo", the button says "See the Demo"). One name per destination across nav, body and footer. The footer groups links as Features, Get started and Company, with legal links beside the copyright line.
- **Actions:** one ink primary per view. The nav CTA stays an outlined secondary. Every page ends on the close (plate, one primary) and the footer.
- **Surfaces:** alternate bands so the page has a beat: page, white band with hairlines, at most one ink band, frame band, photo, plate close. Colored plates (blurred color fields, halftone dots, grain, from `marketing/animations/flockwork.css`) are only for the hero, the page's one callout, the close and the auth pages. The home page's callout is the demo invitation before the FAQ. Tour scenes are frame-colored windows with a border and float shadow, raised off a white band; the tall sign-up card's phone runs off the card's bottom edge.
- **Product scenes:** recorded from `marketing/animations`, showing real UI and only what the product does today. Crop each to the part that tells its story (no repeated sidebars, crumbs or titles), fade the bottom edge instead of cutting it, and hold each beat about 2.5s. Stacked layers swap in sequence, never crossfade, and scenes record at the default quality 75 (lower qualities leave ghosts of faded layers).
- **Phones:** never shrink a desktop frame until its text is unreadable. Crop to the readable region instead: the hero shows its phone mock, tour scenes drop the project's side column, the Planner drops the app sidebar.
- **Layout:** pair words and scene in rows (words left at 260px, scene right). No sticky rails or columns that only look full while scrolling.
- **Icons:** use the app's own tool icons in their tool colors. In tour rows the icon sits above the name, so a wrapped title and its line share one left edge. No icon tiles.
- **Dark mode:** every section has a dark treatment. The hero field becomes ink with a low amber glow; the ink band becomes the one light panel.
- **SEO and AEO:** each page gets its title, meta description, canonical link, Open Graph and Twitter tags from `marketing_head`, with one h1, ordered h2/h3, and alt text that describes what each scene shows. A JSON-LD `@graph` carries Organization, WebSite and the page's type (SoftwareApplication, WebPage, AboutPage, ContactPage, Article or HowTo) and a BreadcrumbList on pages below the top level. A page that answers questions shows them as a visible FAQ and generates its FAQPage JSON-LD from the same array. Add each new page to `sitemap.xml` and the Pages list in `llms.txt`.
- **Copy:** plain category words over slogans, and no claim the product can't back today.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-09 | Sticky public header, transparent at the top and blurred after scroll, with a desktop Features panel and visible phone links | Josh asked for a snazzier header once the marketing pages existed |
| 2026-11-09 | Shorter interior hero fields share the home plate language, with breadcrumbs inside the feature hero and ink/amber dark mode | Josh asked for a snazzier header once the marketing pages existed |
| 2026-11-09 | Marketing head tags and JSON-LD come from `marketing_head`, including expanded page types and breadcrumbs below the top level | One helper keeps visible page metadata, social tags and answer-engine structure consistent across every public page |
| 2026-11-09 | Toasts sit top center on every screen size | Josh asked for centered toasts instead of top right |
| 2026-11-09 | Toasts use Ding | Josh asked for every toast, error message and upload status to use Ding |
| 2026-11-09 | Voice orb in the Planner is amplitude-driven and loops | Josh asked for a pulsing, vibrant, lifelike voice module on the build-as-you-go Planner |
| 2026-11-04 | Meal trains use one All Details form and deterministic slot previews, with autosave and one final Add action | Josh chose All Details because alternating option clicks, typing and advancement is less efficient. Existing active meal drafts open in the new form with their pending work preserved. |
| 2026-10-30 | First direction "Fellowship Ledger" (paper, Sentient, Atkinson) rejected | Josh: felt "AI", especially the fonts and colors |
| 2026-10-30 | Direction "Warm Studio" adopted | Josh: premium but approachable, Basecamp meets Linear/ElevenLabs, respectable yet casual, tangible interactive elements with depth |
| 2026-10-30 | Mattone for wordmark and page headlines | Josh asked for it; limited to display so it reads as a signature, not noise |
| 2026-10-30 | Refined radii, padding, spacing and type sizes (v2 scale) | Josh: "refine the border radii, padding, spacing, and font sizes" |
| 2026-10-30 | Tabular figures only in aligned columns | Mona Sans tabular figures render a dotted zero |
| 2026-10-30 | Preview built as HTML by Codex gpt-6-astra (no OpenAI key for image mockups) | Exact fonts and values; the approved v2 preview is the reference for the Tailwind theme |
| 2026-10-30 | Build-as-you-go Planner replaces the Keep/Edit/Drop review queue for new flows | The Project stays primary, choices visibly change pending work, direct edits happen in context, and one final Add action defines acceptance |
| 2026-11-02 | Screens organized around one question each, with role-specific Home, Project status and guidance strips, tabs and a side column | Josh: pages lacked hierarchy, flow and guidance; mockups approved on the redesign canvas (claude.ai/artifact/2yvhpGTykeuUer6caYT93T) |
| 2026-11-02 | Four-kind button grammar; row actions move behind ⋯ menus | Josh: buttons were inconsistent and "slapped on" |
| 2026-11-02 | Header wash (blob gradient + grain) adopted; ASCII texture rejected | Josh asked for faint, subtle color and personality; ASCII would have needed monospace |
| 2026-11-02 | Header wash drifts between pages over 1600ms, the one motion past 300ms | Josh asked for the blobs to change "slowly and subtly" on page transitions, "smooth and buttery" |
| 2026-11-02 | Formation mark (three birds in a V, gold lead) | Josh picked it from four concepts and tuned the shapes himself in a playground |
| 2026-11-02 | Mark lead is deeper sunlit #D69000, themeable via `--color-mark` | Plain sunlit faded on off-white; Josh chose deep sunlit over clay and wants themes to recolor the mark later |
| 2026-11-02 | Sidebar direction A, "Quiet list": church name and switcher at the top, nav with Notifications in the list, account row pinned to the bottom with an upward menu | Josh approved A. Settings, Profile and Sign out move into one account menu. |
| 2026-11-02 | On phone, a five-tab bottom bar replaces the top bar with a menu button. The bell carries Notifications and the avatar opens the account sheet | Josh approved A. Amends the earlier rule that the phone sidebar collapses to a top bar with a menu button; one-tap destinations and a visible unread count replace the hidden menu. |
| 2026-11-02 | Churches choose their mark color on Settings (presets or custom hex) | Josh wanted the mark to follow a church's own theme, set by an Admin |
| 2026-11-02 | Dark mode, chosen per device; the church Admin still picks the theme color | Josh asked for light and dark; dark is personal, the color is the church's |
| 2026-11-02 | Notifications split into "Needs you" (plain rules: unread mentions, pending Invitations, open assigned Tasks, claimed Slots from today on) and "For your information" grouped by Project; the bell counts only unread "Needs you" | First build from the Notifications brainstorm (no AI): the page should say what needs an answer before anything else |
| 2026-11-02 | A Planner outage (error, or 20s wall-clock budget including retries) shows a calm break panel instead of a dead end; "Build it myself" is a visible secondary action on the Planner start | Answers and preview work are kept, so the Leader can finish by hand with the same Project tools; the Planner never leaves a spinner or a blank page |
| 2026-11-02 | Planner preview rows stream in as the model produces them (throttled to about 200ms); a prepared question still waits for Continue | Items are visible earlier without changing what Continue accepts; the final render is authoritative |
| 2026-11-02 | Person avatars: initials on ten soft hues from the header wash, picked by a stable hash of email (name as fallback), shown wherever a name appears; stacks cap at three plus "+N" | Josh asked for initials avatars that echo the wash and are unique per person. `Zlib.crc32` keeps a color fixed across restarts (`String#hash` is seeded per process). The optional two-blob gradient was left out because DESIGN.md keeps gradients to the header wash |
| 2026-11-02 | Build-as-you-go Planner is a fixed, centered stage (880px max, 340px question column) instead of about two thirds preview; the Planner question uses the ordinary heading scale, not Mattone; the skeleton shimmer is a second, looping motion exception | Owner approved in the Planner redesign review (claude.ai/artifact/UqHH6FmjAHSx2C5pQzFSha). The wide preview sat mostly empty beside a cramped question, and DESIGN.md contradicted itself on Mattone for the question |
| 2026-11-02 | Avatars become 32% squircles on B's 135-degree wash with a faint top highlight; a Person pill carries names in running text; the avatar wash is a second sanctioned gradient | Owner picked the squircle with the washed gradient from the avatar directions review. The hash, the ten hues and the contrast are unchanged. Lists keep the avatar alone, since the row already holds the name. |
| 2026-11-02 | Away dates are typed in the person's own words, and the AI only proposes date ranges; nothing saves until the person confirms, and a failure falls back to the manual date fields | Brainstorm Profile P2: a misread date is a real error, so the confirm step is required. The model returns dates only, with no names or notes |
| 2026-11-02 | An away note is visible to the person who wrote it only; Leaders and Admins see dates ("Away until Nov 9", "Unavailable Mar 1 to 14") | Brainstorm privacy guidance: "Leaders see 'Unavailable Mar 1 to 14,' never the words you wrote" |
| 2026-11-02 | Someone away today is not counted as overextended and is listed under Away | Brainstorm P2: the serving limit was unfair to people who are simply away |
| 2026-11-02 | Leaders of an active Project can open Oversight to see the urgent lists and Away dates; settings and the cross-church involvement table stay Admin-only | Check-ins need a Leader surface; the brainstorm's "Leader or Admin" rule. The counts across the whole church remain Admin data |
| 2026-11-02 | A check-in is logged by a Leader or Admin with a date and an optional note; the note is Admin-only, and Leaders see the date and the person who logged it | Brainstorm O1 and its "Questions for you": admins only for check-in notes, the same as Person notes today |
| 2026-11-02 | Someone checked in within 30 days leaves "May need a check-in" until the window passes | Brainstorm O1: a recent check-in lowers the urgency. The brainstorm names no window, so 30 days is a chosen starting point |
| 2026-11-02 | The check-in card's summary sentence sees an opaque id and counts and dates only; the reply is kept only if every number and date in it was passed in and it has no judgment words, otherwise the template shows | Brainstorm O1: the model must not see names, and it must not turn counts into pastoral judgments. Names are not redacted and returned: the model never receives them |
| 2026-11-02 | The AI summary is generated in a background job and cached per person for their current counts, with a one-hour memory of a failure | Brainstorm: "one run per church per day, cached"; keying on counts means a new check-in or project regenerates it at once, without a daily sweep |
| 2026-11-02 | Directory status chips are 4px badges, not pills; "Never asked" takes the sunlit need fill | DESIGN.md allows only the Person pill as a pill. A never-asked Person is an open need, the one thing sunlit marks |
| 2026-11-02 | The People directory and person page stay Admin-only; Leaders still log check-ins from Oversight and get no person page | People is Admin-only today. Opening it to Leaders would expose involvement and notes, so the brief's "follow the existing policies" was read as no widening |
| 2026-11-02 | Directory filters are a tab bar of plain links with counts, carried as `?filter=` beside `?query=` | Filters are shareable URLs and work with live search, which keeps the filter in a hidden field |
| 2026-11-02 | The person page leads with a profile header and five sections; Edit details moves the form to its own page | The owner asked for a person page, not an edit form. Each section answers one question and keeps Admin-only data to Admins |
| 2026-11-02 | Away dates on the person page show dates only, as Oversight does; the note stays with the person who wrote it | Away notes stay private to their owner, so no role sees the note in a directory or on a person page |
| 2026-11-02 | The "most Slots" highlight is now a thank-you: "Thank you, Ruth: 14 Slots this year.", with no rank and no "most"; the AI thank-you draft from the brainstorm is not built | DESIGN.md rules out leaderboards, and the brainstorm says the ranking should go. Admin-only, since the involvement counts are Admin data |
| 2026-11-03 | The landing page lives on its own: larger Mattone headline and taller buttons, two primary CTAs, and product scenes on colored plates (blurred color fields, halftone dots, grain) recorded as animated webp from `marketing/animations` | Josh: the marketing page "should kind of live on its own" and can break font and button size rules; plates after conduit.ai's product shots. The app itself keeps every rule above |
| 2026-11-03 | One text link style (`.link`, a hairline underline) replaces the ad hoc `underline` classes; sign-in, sign-up and invitation pages split into the form beside the recorded sign-up scene, which drops away below 900px | Josh: the fat underlines were "NOT looking good" and the auth pages should fit the home page |
| 2026-11-03 | The church name leaves the top of the sidebar; it stays in the account row, and the account menu offers Switch church to someone in several Organizations | Josh: "we have it down below next to the user menu" |
| 2026-11-03 | Profile is vertical tabs (Details, Notifications, When you're away, Appearance, Your Involvement) using `nav-item` styling and the tabs controller, which remembers the last tab | Josh asked for vertical tabs to make the long profile page feel more focused |
| 2026-11-03 | Project lists show a small 3:2 banner thumbnail (`projects/_thumbnail`), a quiet frame tile with the folder icon when there is no photo | Josh: bring the banner images in, small |
| 2026-11-03 | Get involved is discovery first: one Needs a hand card lists the three Projects short on people soonest, each a link through to the Project to sign up, then the Open to you cards and Teams you're on. Spots are no longer claimed from Get involved itself | Josh: the page was "just like... a list of time slots"; people should click through |
| 2026-11-03 | Every visible button label uses Title Case; non-button interface copy remains sentence case | Josh requested Title Case for all buttons |
| 2026-11-04 | Redirects back to the same page morph in place and keep scroll (`turbo_refreshes_with :morph`); a Project page refreshes live when anyone changes it or its Tools; flash moves to toasts; destructive actions confirm in a styled dialog | Josh asked for the refinement layer: notices were lost on pages that never rendered flash, and every action reloaded the page to the top |
| 2026-11-04 | Skills on People (seeded list plus free tags, set by the Person or an Admin) and Skills needed on Projects; the Team tab suggests up to five People by plain rules, and Leaders see only matched skills | Josh picked the AI-enablement follow-up: the Planner plans roles and now Skills needed, while ranking People stays in Ruby per ADR 0002 |
| 2026-11-06 | Status-strip values use a 20/24 Mona Sans 600 `stat` size; no-photo Project thumbnails are tinted by the Project's lead Tool with that Tool's icon; Rename moves from beside the Project title into the ⋯ menu | Josh approved these from the UI council review: the org-wide counts did not read as the headline, the gray folder tiles read as broken images, and the inline link crowded the only display heading |
| 2026-11-08 | Landing page rewritten as a StoryBrand page: plain-category headline, the in-between timeline, Planner section, sticky-rail tour replacing the tabs, a short Ephesians 4 section, frequency-based close; landing body copy at 17–18px and section gaps of 120–160px extend the 2026-11-03 landing exemption. | Josh found the page bland from hero to footer and wanted a pastor to understand what it is, the gap it fills, and day one, at a glance; the why is Ephesians 4. |
| 2026-11-08 | Landing page visual pass from Mobbin references: the hero wash becomes a full-viewport warm field the scene breaks out of; the in-between is a white band with hairlines; the Planner is a full-bleed ink band (on-ink text, the scene breaking the right edge); the tour section tints toward the current scene's plate tone; the why section pairs the statement with the Alvarez family photograph on a sunlit-soft panel; the close lands on a footer that ends in the wordmark running off the bottom edge in Mattone Bold. The ink band and the photograph are new surfaces for the marketing page only | Josh: the merged copy was "in a better place" but the page "really feels lackluster"; he picked all six moves from the Mobbin board (Legora, Cosmos, Passionfroot, Craft, Fixa, Linear, incident.io, sweetgreen, Equals). The app keeps every rule above |
| 2026-11-09 | Landing council run (5 rounds, Opus, GPT Sol, Grok): colored plates only on the hero, the Planner callout, the close and auth; tour scenes cropped to the project without sidebar or title and set as paired rows instead of the sticky rail; the tour tint removed; the Planner scene tells three questions; one left edge on `--lp-max`; a visible FAQ with FAQPage JSON-LD, canonical and social tags, `sitemap.xml` and `llms.txt`; the Marketing pages rules above | Josh: plates "just for the hero or special callouts" and paired rows; every reviewer docked the empty rail column and the repeated full windows |
| 2026-11-11 | Landing tour scenes become raised windows on a white band with stacked icons; the demo invitation is the home callout plate; the footer drops "On this page" for three link groups | Josh found the flat scenes and inline icons "blah", wanted the demo ask more emphatic, and the footer better organized |
| 2026-11-11 | Landing letter becomes a tilted sheet of paper with a clipped photo print; the example photos become an overlapping album of prints that straighten on hover, with plural captions; the timeline's start names its sources as chips; the tall card's phone is drawn larger with its bottom 15% under the card edge | Josh asked for Basecamp's angled letter, a more creative photo treatment, and a fix for content overflowing the phone bezel |
| 2026-11-12 | The top bar's shape carries into the app: buttons are fully round and 36px tall, inputs 12px and 36px, tiles 16px, panels 20px. Tabs, quick filters, status chips and badges keep their own shapes | Josh asked for the new nav's look across the app. Round now means "press me"; filters and facts stay distinct so they are not mistaken for actions. Replaces "No other pills" |
| 2026-11-12 | Copy and icon cut: page subtitles, sort explainers and field hints that restate their label are gone; tool headings inside a tab are for screen readers only; decorative icons beside labels (tool headings, "+" on Add buttons, menu and section nav icons, Comment and Reply) are removed | Josh: every piece of text and every icon must serve an immediate purpose for the task, or go. Privacy, consequence, limit and unsaved-state lines stay |
| 2026-11-12 | Desktop pages sit on a white sheet over the `frame` canvas, as phones already did; major blocks get 40px between them; strips and aside panels take the `page` tint | Josh asked for more surface contrast and breathing room. One sheet keeps every list legible on white and makes the page read as an object under the floating bar. Replaces the edge-to-edge white page |
| 2026-11-12 | UI council run: the banner ghost tile moves into the Project's ⋯ menu as Add Banner; directory rows drop the "Not serving" line; Leader and Admin Home skip empty Your Tasks and Coming up; narrow single-column pages center in the sheet; the sign-up sheet's need badge appears only from two open spots up; the Planner shows a disabled Continue from the start, with Talk It Through as a plain secondary button below the actions; no-photo thumbnails show a 24px icon (`ink-2` on `hairline` without a Tool); the People directory groups rows by first letter; the skill filter applies on change; the People search and skill filter share one row | Josh approved the three doc departures (banner, directory line, one-spot badge) from council findings; every reviewer docked the tile above the title and the repeated directory text, Josh has not yet reviewed the rest (empty-section skipping, letter groups, filter on change, the "Not yet asked" chip name), which came from council findings during the run |
| 2026-11-12 | No-photo Project rows drop the tinted tool tile; the Planner's inline xAI voice line is removed (the Privacy page covers it) and Continue appears only after an answer is chosen | Josh approved both from round 6 of the council run: all three reviewers docked the tiles, and two docked the xAI line and the grey disabled Continue |
| 2026-11-13 | The Public link gets its own sign-in: one field for an email or mobile number, a 6-digit code in a single wide-tracked field, and a name step only for new helpers. Helpers then claim on the public page itself | Josh asked for "easy as pie" sign-in from a shared meal train link. The staff sign-in page was email-only and sent nothing to anyone the church did not already know. Claiming stays on the public page because the link promises Leaders that Team names and private Tools stay hidden. After the UI council: the tapped Slot is claimed when sign-in finishes, the public list groups by week like the Sign-up sheet, rows lead with day and time, and the row and toast share one phrase and the sunlit check |
