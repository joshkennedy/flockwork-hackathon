---
name: remake-homepage-animations
description: Re-record the landing page's animated product images (animated webp) from the stageshow scenes in marketing/animations, after checking each scene still matches the current app. Use when asked to "remake the homepage animations", "redo the landing animations", "update the marketing images", or after UI changes to a screen a scene shows.
---

# Remake the homepage animations

The landing page (`app/views/landing/show.html.erb`) shows animated webp files rendered from hand-built
stageshow scenes in `marketing/animations/scenes/`. Each scene is a simplified, authored illustration of a
real Flockwork screen, not a screen recording, so a remake has two halves: bring the scenes up to date
with the app, then re-record.

What follows the app on its own at record time: colors, radii, shadows and component classes (the scenes
load the app's compiled Tailwind build and use its classes: `btn`, `badge-need`, `person-pill`, `avatar`,
`tab-link`, `nav-item`), and icons (`generated/icons.json` is rewritten from `ApplicationHelper::ICON_PATHS`).
What does not: layout, copy, and which parts a screen has. Those live in each scene's `.tsx` and `.css`.

## 1. Check each scene against the app

`marketing/animations/scenes/manifest.ts` lists every scene. Each `.tsx` opens with a comment naming the
screen it shows and its story. For each scene:

1. Run the app (`bin/rails server`), open `/demo` and sign in with the role the scene shows. Visit the
   screen the scene draws (the hero is the Meal Train for the Alvarez Family project, sign-up sheet tab,
   desktop as Admin, and the same project at 390px wide as Volunteer).
2. Open the scene: `cd marketing/animations && npm run dev`, then `http://127.0.0.1:5199/?scene=<name>`.
3. Compare the two. Update the scene where the app's structure, labels or flow changed (a renamed tab, a
   new status-strip cell, a different button label, a new step in the claim flow). Keep the scene's
   restraint: real words only on what the story is about.
4. If the story itself changed, update the image's `alt` text in `landing/show.html.erb` to match.

When nothing structural changed, skip straight to recording.

## 2. Record

```sh
bin/marketing-animations            # every scene
bin/marketing-animations hero       # one scene
```

It rebuilds the app CSS, refreshes the icons, records each scene frame by frame on stageshow's virtual
clock (no dropped or doubled frames), and writes `app/assets/images/marketing/<out>.webp` (animated,
looping, transparent ground) and `<out>-still.webp` (the poster frame, served under
`prefers-reduced-motion`). It fails loudly when a scene's last frame does not meet its first, which would
make the loop jump. Pass `--keep-frames` to inspect the PNG frames in `marketing/animations/tmp/frames/`.

Needs Google Chrome and libwebp (`brew install webp`).

## 3. Verify before reporting

- Look at every `-still.webp`, and a contact sheet of the frames (`--keep-frames`, then
  `magick montage $(ls tmp/frames/<name>/*.png | awk 'NR%15==1') -tile 3x -geometry 555x310+4+4 sheet.png`):
  the story reads beat by beat, nothing pops, nothing is cut by the stage edge.
- Open the landing page in light and dark mode. The scenes have a transparent ground, so both should look right.
- `bin/rails test test/integration/landing_test.rb`.
- Report each file's size (the script prints them). They have run 75 to 475KB each; the whole set is about 1.9MB animated, and every scene below the hero lazy-loads.

## Adding or changing a scene

Load the user's `/stageshow` skill first and follow it: it holds the framing, craft and motion rules
these scenes were built to. Then in `marketing/animations`:

- Write `scenes/<name>.tsx` (and a scoped `.css`), using the pieces in `scenes/flockwork.tsx`
  (`Icon`, `Wordmark`, `Avatar`, `PersonPill`, `Sidebar`) and the kit in `kit/`.
- Export `meta = { out, seconds, poster }` from the scene file; `scenes/manifest.ts` finds it on its own.
  `seconds` is roughly one pass of the script, `poster` (ms, at least 2000) a settled beat that tells the
  story alone. Optional `offset` (ms) rotates where the loop starts, so scenes side by side (the three
  cards) don't move in lockstep.
- Put the scene on a plate: `fw-plated` on the Stage, `<Plate tone="..." />` first (tones: sunrise,
  meadow, lake, clay, dusk), the window inset about 48px top and sides and running off the bottom.
- Show it on the page with a `<picture>`: a `(prefers-reduced-motion: reduce)` source for the still, and
  the animated webp as the `img`, with its width and height at the stage's design size.

Gotchas, each learned the hard way:

- The kit resets `p`, `ul`, `li`, `dl`, `dt`, `dd`, `button` and the like inside a stage so host CSS can't
  leak in. That also strips the app's element-based styles (`.status-strip dt`), so scenes use `div` and
  `span` and restyle those parts in the scene's CSS.
- `Count`'s `format` collapses spaces ("14of29"). Put the words outside: `<Count value={14} /> of 29 dinners`.
- `--ss-shadow-hero` spreads wider than a 24px gutter and leaves a cut line at the stage edge. Use a
  tighter shadow or widen the gutter.
- The script must end exactly where it began, cursor included (move it back to its rest point, and set
  the cursor's `idle: false`). The recorder measures the loop from the poster frame and searches up to 3s
  either side of `seconds`; it fails loudly when no frame matches.
- The first second or two render a hair differently (corners, antialiasing), which is why the loop is
  measured from the poster and the webp is cut from the second pass.
- Text whose box re-measures each pass (`Swap`) or loses its layer mid-loop drifts by a subpixel and breaks
  the seam: crossfade in one fixed grid cell instead, and give windows `will-change: transform` from frame one.
