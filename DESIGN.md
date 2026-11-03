---
# gstack: design-md-format=spec
name: Flockwork
description: Warm Studio. Premium but approachable, respectable yet casual; Basecamp's warmth with the polish of Linear and ElevenLabs. Calm flat panels, tangible controls with real depth.
colors:
  frame: "#F3F2EF"
  page: "#FAFAF8"
  panel: "#FFFFFF"
  border: "#E6E4E0"
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
  badge: 4px
  control: 6px
  nav: 8px
  tile: 10px
  panel: 12px
  device: 28px
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
  control-h: 32px
  control-h-sm: 28px
  input-h: 36px
  input-h-phone: 44px
  answer-h: 48px
  phone-action-h: 48px
  sidebar-w: 232px
  topbar-h: 48px
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-ink}"
    rounded: "{rounded.control}"
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
    rounded: "{rounded.control}"
    shadow: "0 1px 2px rgba(20,20,19,.06), inset 0 -1px 0 rgba(20,20,19,.04)"
  button-text-danger:
    textColor: "{colors.danger}"
  input:
    backgroundColor: "{colors.panel}"
    borderColor: "{colors.border}"
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
    rounded: "{rounded.nav}"
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
- A warm-gray app frame with a left sidebar holding one white content panel (12px radius, 8px inset), like Linear and ElevenLabs.
- Near-monochrome ink; a single gold accent (sunlit) reserved for open needs, the kept check and celebration.
- Mattone, a heavy wide display face, only for the wordmark and page-level headlines; Mona Sans for everything else.
- Interactive things are tangible: raised tiles and buttons with layered soft shadows that press in. Panels and lists stay flat.
- AI Suggestions are ghost tiles (dashed, muted). A Leader's Keep turns them solid with a gold check. People are always shown by name, never scored.

## Colors

**Strategy:** Restrained. Ink carries text and the one primary action per view. Sunlit appears only as a fill (`sunlit-soft` behind "1 spot left" and team notes) or as an icon (the kept check), never as text on white. Danger is for destructive text actions only. Tool colors appear only on 14–16px Tool icons, the way Linear colors status icons.
**Light or dark:** Both, chosen per device on Profile (Light, Dark, Match device; kept in an `appearance` cookie, default follows the OS). Dark sets `data-dark` on `<html>` and swaps every token for warm near-blacks: frame #141413, page #191918, panel #1D1D1B, border #2E2D2A, ink #F2F1ED, ink-2 #AAA8A2, sunlit-soft #3A2D0E. Ink stays the primary action, so primary buttons turn light with dark text. Shadows deepen and gain a faint top highlight so raised tiles still read as raised. The default mark brightens to sunlit in dark; a church's own color is set inline and stays as picked. Disabled buttons sit on `nav-active` in dark, since `frame` is darker than `panel` there. Both layouts set `theme-color` (frame in light, #141413 in dark) so phone browser bars match.
Contrast (measured in the preview): `ink-2` on `panel` 6.49:1, `ink-2` on `frame` 5.80:1. `ink-3` is only for non-essential hints (keyboard numbers, breadcrumb separators), never body text.

**Mark (Formation):** three round-capped chevrons flying in a V on a 24-unit grid; the lead bird is 1.15x the size of the two `ink` followers (stroke 2.8, lead 3.22). The lead is `mark` (#D69000, a deeper sunlit: plain sunlit is only 1.8:1 on `page` and disappears); on dark it goes back to bright `sunlit`. The lockup is `layouts/_wordmark`, an inline SVG set 15px tall beside the wordmark with an 8px gap so its strokes match Mattone Bold; the lead reads `--color-mark`, which each layout sets on `<body>` from the church's `mark_color`. An Admin picks it on Settings from seven presets (Deep sunlit, Copper, Clay, Berry, Teal, Forest, Cobalt) or a custom hex. The mark color only recolors the mark: in-app `sunlit` keeps its meaning for open needs and the kept check. The favicon is served by `IconsController` at `/icon.svg?c=<hex>` (followers white in dark browser chrome; the default lead also brightens to sunlit there). `public/icon.png` is the app icon: the mark on a full-bleed `page` tile, so iOS never fills the corners black. Never add a fourth bird or set the mark without its colored lead.

## Typography

**Mattone** (Collletttivo, designed by Nunzio Mazzaferro, SIL OFL 1.1, self-hosted from `github.com/collletttivo/mattone` woff2, Regular/Bold/Black) is the signature: the "Flockwork" wordmark (Bold 18px) and page-level headlines (Regular 30/36 desktop, 24/30 phone): Project names on their page and the Oversight headline. The Planner question is not a page headline: it uses the ordinary heading scale in Mona Sans. It is wide and heavy, so it never sets body, buttons, labels, numbers, or anything below page level.
**Mona Sans** (GitHub, Google Fonts, variable weight and width) sets all UI and body at normal width: headings 600 15/20, body 450 14/21 (16/24 on phones), meta 13/18 in `ink-2`, labels 500 12/16, buttons 500 13/16 (phone primary 600 15).
Numbers: Mona Sans's tabular figures carry a dotted zero, so use `tabular-nums` only in aligned numeric columns (Budget totals, tables). Times, dates and counts in running text use default proportional figures with a plain zero.
Sentence case everywhere. No tracked all-caps, no monospace decoration, no italic display.

## Layout

App shell: `frame` background, 232px sidebar (wordmark, church switcher, nav items 32px tall with 2px gaps, Notifications in the list with its unread count, and the account row pinned to the bottom), content in one `panel` inset 8px. Topbar 48px with a breadcrumb in 12px `ink-2`. Panel padding 28px desktop, 16px phone. Major blocks separated by 28px; groups by 20px; tiles by 8px (12px on phones). The build-as-you-go Planner is one fixed-width stage, at most 880px and centered in the panel: a 340px question column beside the preview, which takes the rest. Below 1024px the two stack, the question first. The Project name is the only display heading; the current question uses the ordinary UI heading scale. Oversight is two flat name lists side by side. Phones: a top bar holds the wordmark, the bell (Notifications, with its unread count) and the account avatar; a five-tab bar at the bottom holds the destinations, padded for the safe area; 16px gutters; one full-width primary action per card. During planning, show the current choice with the most recently changed preview row and an explicit View all route so the work is never reduced to a count.

**Every screen answers one question.** Home opens "Hi <first name>" (no time-of-day greeting: the app runs on UTC and keeps no church time zone) and works the same for every role, top down: pending Invitations, then "Your Tasks" (open Tasks in due-date order, Done in place), then "Coming up" (your upcoming sign-up Slots). Below that the role's own view. Admins see "is the whole church covered?": a status strip of org-wide counts, then every active Project sorted by need with its Leaders and status (header wash tint `wash-admin`). Leaders see "what do my Projects need next?": one raised tile per Project they lead with the single action that unblocks it (Fill spots, Assign tasks, Plan it). Volunteers see their Projects, then "what's still needed?" (open spots this week on their Projects) and then "how else can I help?" (open Teams they are not on), tint `wash-volunteer`. The Projects index groups rows under Happening now, Coming up, No dates yet, Ended and Done, with When and Status columns in plain counts. A Project page stacks title and description (Plan more and a ⋯ menu on the right), a status strip (When, Covered in spots, Next open or Assigned/Next due, Team), a guidance strip (`sunlit-soft` fill, the open need in one sentence, the view's one primary action), then tabs: every enabled Tool except Recipients, Tools with content first, plus Notes, plus a Team tab that links to the Team page. Tabs switch client-side and remember the last tab per Project; every panel is server-rendered. Under the tabs the active Tool takes the wide column and a 320px side column holds Recipients with their care notes and Sharing and ownership. The Sign-up sheet shows This week and Next week as flat rows, with Past and Later folded away; on phones an open Slot keeps its raised tile. The Team page lists Members (Leaders first, removal behind ⋯) with inviting and Invitations in a side column for those who manage the Team. Get involved shows open Teams you are not on as cards with their open need and a Join the Team button, then the Teams you are on. Archived and Deleted lists use the same row grammar as the Projects index.

## Elevation & Depth

Three levels only. Flat: panels, lists, team notes (border or tint, no shadow). Raised: answer tiles, open Slots, kept Suggestions, highlight tiles (`0 1px 2px rgba(20,20,19,.05), 0 4px 12px rgba(20,20,19,.04)`). Floating: popovers, menus, dialogs, toasts (`0 8px 24px rgba(20,20,19,.12), 0 2px 6px rgba(20,20,19,.06)`). Buttons carry their own inner highlight and press shadow (see components). Never a zero-offset glow, never a card inside a card.

## Shapes

Badges 4px, buttons and inputs 6px, nav items 8px, tiles 10px, panels and popovers 12px, phone device frame 28px. Person avatars are 32% rounded squares (a squircle whose ring follows the shape). Only status dots and the Person pill are fully round. No other pills.

## Components

- **Primary button:** ink fill, white 13/500 label, 32px tall (28px small, 48px full-width on phones), inner top highlight plus two soft shadows. Hover lightens to `ink-hover`; active presses 1px with an inset shadow; focus-visible is a 2px ink outline offset 3px with a panel-colored gap; disabled is `frame` fill with `ink-2` text and no shadow. One per view.
- **Secondary button:** white with border and a hairline bottom inset; same press behavior.
- **Text button:** no chrome, `ink-2`, hover tints with `hairline`; danger variant in `danger` with `danger-soft` hover.
- **Planner answer tile:** raised tile 48px tall, 14px padding, radio on the left, keyboard number 1–4 in `ink-3` on the right; hover darkens the border to `border-strong`; selected shows an ink border and filled radio; pressed sinks 1px.
- **Pending Planner work:** generated work stays on the `ghost-fill` surface with a dashed `ghost-border` and one "Suggestions · not added yet" state label for the whole preview. Tool contents use compact rows rather than a card per item. Edit opens fields in place; Remove lives inside that edit area, and Undo appears after removal. There is no Keep/Edit/Drop queue. One final Add to Project action accepts every visible, non-removed item.
- **Planner choices:** answer tiles retain their raised treatment and show an unmistakable selected radio and ink border. A typed answer is the selected answer too: it shows as "Your answer" above the choices, and Continue advances after the same preparation. Selecting an answer prepares the visible preview; Continue only advances after that preparation completes. While the Planner works, the preview shows dashed skeleton rows with the text "Building the Sign-up sheet…", and each complete item appears as its own row as it is generated (rows appear in order and never repeat). The skeleton stays until the step finishes, and Continue is enabled only after the final result replaces the streamed rows. Back, Finish with this, and Save and leave are quiet actions. The final primary changes to Add to Project in the same organization.
- **Slot (phone):** claimed Slots are flat rows (date 14/600, "✓ Ruth Bennett" in `ink-2`); open Slots are raised tiles with date, a `badge-need` ("1 spot left") and a full-width primary "I can bring dinner"; after claiming the tile flattens and shows "You're bringing dinner" with the sunlit check.
- **Inputs:** 36px tall (44px phone), 6px radius, `border`, placeholder in `ink-2`; the dictation mic is an icon button inside the field.
- **Button grammar:** four kinds of action, one look each. The view's next step: ink primary, one per view, in the header or guidance strip. Add to a section: small secondary with a plus, right of the section heading, always "Add …". Do the thing (Volunteer-facing): small secondary worded as the person would say it ("I can bring dinner"). Manage it: a ⋯ icon button opening a menu (Edit, Duplicate, Archive, then Delete last in `danger`). No inline Edit/Delete on rows, no bare-text section actions. List columns follow the same rule: one ⋯ menu per column header.
- **Sidebar:** the church name sits at the top in a row with a 24px initials tile. It reads as a plain label until the Person's email belongs to several Organizations; then a chevron shows and the row links to the choice page. Below it, nav items in this order: Home, Projects, Get involved, People and Oversight (Admin only), then Notifications with its unread count in `ink`. Settings is not in the nav. The current page is `nav-active` with `aria-current="page"`.
- **Avatar:** a person's initials (first letter of the first and last name, one letter for a one-word name, "?" for no letters) on a 32% rounded square: 20px `sm` in meta lines, pills and stacks, 28px by default in lists, 56px `lg` on Profile and the person page. The fill is a 135-degree wash from one of ten hues in the header wash family (`avatar-hue-0` to `9`, tokens `avatar-0` to `9`) into the next hue around the wheel, using B's light and dark palettes. The hue is chosen by `Zlib.crc32` of the person's email, or of their name when there is no email, so a person keeps one color everywhere and across restarts. Ink initials clear 10.4:1 on the light wash, and `#F2F1ED` clears 7.6:1 on the dark wash, on every hue. A faint top highlight (`--shadow-avatar`) gives depth without a border. Static avatars never move; one inside a link or button lifts 1px on hover. Beside a visible name the avatar is `aria-hidden`; a bare avatar (the phone top bar) names itself with `role="img"`. Several people show as an overlapping stack of up to three plus a "+N" tile, and each avatar's ring follows the same shape in the surface behind it (2px, 1.5px in 20px stacks).
- **Person pill:** a name in running text (task and comment authors, meta lines, Slot claimers, notifications, Invitations, Home leaders). A `hairline` pill, 24px tall, with the 20px avatar flush at its left end (a 2px inset) and the name in 13/18 `ink`. No border, so it reads as a label rather than a button. Several people share one pill: the overlapping stack, then their names. A pill that links to the person gets a gentle `nav-active` hover; a static pill never changes on hover. Where the row is already the container (Team members, People, Oversight, Invitations and Recipients lists, the sidebar account row) the avatar sits alone beside the name instead.
- **Account menu:** one popover, used in two places. The sidebar row pins to the bottom (an avatar, name at 13/600, church at 12/16 `ink-2`, updown chevron) and its panel opens upward: identity head, Profile, Settings (only where the Person may manage Settings), a hairline, then Sign out. On phone the avatar in the top bar opens the same items as a sheet above the tab bar. It is a `details` disclosure, so Enter or Space opens it and Tab moves through the items; Escape or an outside click closes it and Escape returns focus to the trigger.
- **Phone tab bar:** fixed to the bottom on `frame` with a hairline top border. It has one column per destination the Person can open (Volunteers see three). Each tab is at least 44px tall, with a 20px icon and an 11px label; the current tab is `ink` and 600. Notifications is not a tab. It is the bell in the top bar, and its count is an `ink` badge. Bottom padding follows `env(safe-area-inset-bottom)`, which needs `viewport-fit=cover` in the app's viewport meta.
- **Tool rows:** the Tasks list is the model. A task is completed by a 20px ring at the left with a 44px hit area; hovering previews the check, and a completed task becomes a sunlit disc with the check, so no "Done" button appears. The title is `heading`, with one meta line of assignee and due date. Due dates read relatively near today ("Due in 3 days", "Overdue by 2 days", "Due Apr 9" beyond eight weeks), with the exact date in the `<time>` title. Comments show as a count ("2 comments", or "Comment" when there are none) without a disclosure marker. Claim stays a small secondary button; Unclaim, Edit and Delete live in the row's ⋯ menu. Schedule items follow the same title-then-meta order.
- **Header wash:** the decorative surface for pages. The avatar wash is the only other gradient. Two or three blurred radial blobs (closest-side radial gradients, 24px blur) at 9–22% alpha in tool or accent colors, plus SVG `feTurbulence` grain at 10% alpha multiplied on top, masked to fade out by 300px from the top of the panel. The tint carries meaning: `sunlit` for sign-up work and Leader views, `tool-schedule` teal for the Admin overview, `tool-messages` orange for Volunteers. Header content sits above it; anything that sits on it (the status strip) gets a 75% white fill. Never behind rows, forms, the Planner, or text that needs 4.5:1.
- **Project banner:** an optional photo above the Project header, in a `rounded-panel` frame with a `border`. It crops to 3:1 on desktop and 2:1 on phones, around a focal point that defaults to center (an AI suggestion can move it, an editor can set it). A photo too small for the crop sits whole on a blurred copy of itself and is never upscaled. With no photo, editors see one dashed ghost tile to add one; the public page shows only the photo.
- **Privacy line:** on every Planner screen, a lock icon and "The planner sees project details. It never sees your people." in 13/18 `ink-2`.
- **Notification list:** two regions on one page. "Needs you" is the top section, newest first, with at most one small secondary action per row: Respond (an Invitation), Mark done (a Task), or Open. "For your information" groups the rest under their Project name (12/16 label in `ink-2`), with plain rows and Mark read. The bell and its sidebar count show unread "Needs you" items only. Both sections use plain rules, never AI copy.
- **States:** empty ("Nothing here yet"), loading ("Thinking…" on the Planner), and error are designed text in the panel, not blank space. The planner error is a calm `sunlit-soft` panel: "The planner is taking a break — you can keep going by hand.", with Retry (secondary) and "Keep going by hand" (text), and it keeps every answer and preview row already given. The Planner's start offers "Build it myself" as a visible secondary action beside the kind tiles.

## Do's and Don'ts

- Do keep AI output as ghost tiles until a human keeps it.
- Do show people by name with plain counts ("4 active Projects", "14 meals this year"); never bars, percentages, red flags or scores.
- Do reserve Mattone for the wordmark and page-level headlines, and depth for things you can click.
- Do keep exactly one primary (ink) button per view.
- Don't use gradients (except the header wash and the avatar wash), purple or indigo, glows, emoji, icon tiles above headings, kicker labels, pills other than the Person pill, avatar walls (more than the three-avatar stack), chat bubbles for the Planner, or cards inside cards.
- Don't set Mattone below 24px or on anything interactive.

## Motion

- **Approach:** minimal-functional.
- **Easing:** enter ease-out, exit ease-in, move ease-in-out.
- **Duration:** press 100ms, hover/border/background 150ms, preview-update emphasis 180ms. Nothing longer than 300ms, with two exceptions: the header wash drifts for 1600ms (`cubic-bezier(0.45, 0, 0.25, 1)`) from the previous page's blob layout and tint to the new page's. Each page's layout comes from its path, the drift never delays content, and `prefers-reduced-motion` skips it.
- **Building state:** the only loop is the skeleton shimmer in the Planner preview (1600ms, opacity only), shown while a step is being prepared, and it is a second exception to the 300ms rule. It stops under `prefers-reduced-motion`, and the text label carries the state without it.
- **The authored moment:** a changed choice produces a short tonal emphasis on the affected preview row after the new content is already visible. Content is never hidden waiting for an entrance animation. `prefers-reduced-motion` removes transforms and makes the tonal change instant.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
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
