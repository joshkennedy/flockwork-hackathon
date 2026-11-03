// Rebuilds the landing page animations from the scenes in ../scenes.
//
//   node scripts/make.mjs            every scene
//   node scripts/make.mjs hero       only the named scenes
//   --keep-frames                    leave the PNG frames in tmp/frames for inspection
//
// Each scene is recorded frame by frame on the kit's virtual clock (so no frame
// drops or doubles), then encoded as a looping animated webp plus a still webp of
// its poster frame, written to app/assets/images/marketing/<out>.webp and <out>-still.webp.
import { execFileSync, spawnSync } from 'node:child_process'
import { mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { build, createServer } from 'vite'
import { chromium } from 'playwright-core'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const repo = resolve(root, '../..')
const images = resolve(repo, 'app/assets/images/marketing')
const args = process.argv.slice(2)
const only = args.filter((arg) => !arg.startsWith('--'))
const keepFrames = args.includes('--keep-frames')

const run = (cmd, cmdArgs, cwd = repo) => execFileSync(cmd, cmdArgs, { cwd, stdio: ['ignore', 'pipe', 'inherit'] }).toString()

// 1. Pull the app's current look and icons, so scenes follow the app without edits.
console.log('Building the app CSS and reading its icons…')
run('bin/rails', ['tailwindcss:build'])
mkdirSync(resolve(root, 'generated'), { recursive: true })
writeFileSync(resolve(root, 'generated/icons.json'), run('bin/rails', ['runner', 'puts JSON.pretty_generate(ApplicationHelper::ICON_PATHS)']))

// 2. The virtual clock is injected before any scene code loads.
const clockBuild = await build({
  root, logLevel: 'silent', configFile: false,
  build: { write: false, lib: { entry: resolve(root, 'kit/clock.ts'), formats: ['iife'], name: 'SSClock' } },
})
const clock = clockBuild[0].output[0].code

const server = await createServer({ root, logLevel: 'error', server: { port: 5199, strictPort: false } })
await server.listen()
const base = server.resolvedUrls.local[0]
const { scenes } = await server.ssrLoadModule('/scenes/manifest.ts')
const chosen = only.length ? scenes.filter((scene) => only.includes(scene.name)) : scenes
if (only.length && chosen.length !== only.length) throw new Error(`Unknown scene in: ${only.join(', ')}. Known: ${scenes.map((s) => s.name).join(', ')}`)

const browser = await chromium.launch(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : { channel: 'chrome' })
try {
  for (const scene of chosen) {
    const { name, out, seconds, poster, offset = 0, fps = 30, scale = 2, quality = 75 } = scene
    const frames = resolve(root, 'tmp/frames', name)
    rmSync(frames, { recursive: true, force: true })
    mkdirSync(frames, { recursive: true })

    const page = await browser.newPage({ viewport: { width: 1600, height: 1200 }, deviceScaleFactor: scale })
    const errors = []
    page.on('pageerror', (error) => errors.push(error.message))
    await page.addInitScript(`${clock};SSClock.installVirtualClock({ fps: ${fps}, epoch: Date.UTC(2026, 10, 3, 15) })`)
    await page.goto(`${base}?scene=${name}`)
    const stage = page.locator(`#${name} .ss-stage`).first()
    await stage.waitFor()
    // Transparent around the scene, so one file sits on the light and the dark page alike
    await page.addStyleTag({ content: 'html, body { background: transparent !important; }' })
    await page.evaluate(() => document.fonts.ready)
    const step = () => page.evaluate(async () => { const c = window.__stageshow.clock; await c.flushLayout(); await c.step(1); await c.flushLayout() })

    // The loop is measured from the poster frame, a settled beat well past the first second or
    // two (where layers are still being rasterized and corners render a hair differently):
    // find the frame one pass later that matches it exactly, searching outward from `seconds`.
    // The webp then starts at the beginning of the second pass, on the script's calm opening,
    // and wraps through the poster, which is seamless because those two frames are identical.
    const expected = Math.round(seconds * fps)
    const posterFrame = Math.round((poster / 1000) * fps)
    if (posterFrame < 2 * fps) throw new Error(`${name}: poster must be at least 2000ms in, past the first frames' rendering noise`)
    const recorded = posterFrame + expected + 3 * fps
    const framePath = (f) => `${frames}/${String(f).padStart(4, '0')}.png`
    process.stdout.write(`Recording ${name}: up to ${recorded} frames `)
    for (let f = 0; f < recorded; f++) {
      await stage.screenshot({ path: framePath(f), animations: 'allow', omitBackground: true })
      await step()
      if (f % fps === 0) process.stdout.write('.')
    }
    await page.close()
    if (errors.length) throw new Error(`${name} threw while recording: ${errors.join('; ')}`)

    // compare exits 1 when the images differ, so read its pixel count rather than its status
    const differs = (a, b) => Number(spawnSync('magick', ['compare', '-metric', 'AE', '-fuzz', '2%', framePath(a), framePath(b), 'null:']).stderr.toString().split(' ')[0])
    let period = 0, closest = { p: expected, d: Infinity }
    for (let offset = 0; offset < 3 * fps && !period; offset++) {
      for (const p of offset ? [expected + offset, expected - offset] : [expected]) {
        if (p <= fps || posterFrame + p >= recorded) continue
        const d = differs(posterFrame, posterFrame + p)
        if (d === 0) { period = p; break }
        if (d < closest.d) closest = { p, d }
      }
    }
    if (!period) throw new Error(`${name}: no frame within 3s of ${seconds}s after the poster matches it (closest: ${(closest.p / fps).toFixed(2)}s later, ${closest.d} pixels off), so the loop would jump. Make the script end where it began.`)
    process.stdout.write(` loop ${(period / fps).toFixed(2)}s`)

    // Any frame of a seamless loop can come first. Start at the second pass's opening, moved on
    // by `offset` ms, so scenes shown side by side don't move in lockstep.
    const start = period + Math.round((offset / 1000) * fps)
    const files = Array.from({ length: period }, (_, i) => framePath(posterFrame + ((((start + i - posterFrame) % period) + period) % period)))
    const animated = resolve(images, `${out}.webp`)
    const still = resolve(images, `${out}-still.webp`)
    run('img2webp', ['-loop', '0', '-min_size', '-lossy', '-q', String(quality), '-m', '4', '-d', String(Math.round(1000 / fps)), ...files, '-o', animated], root)
    run('cwebp', ['-quiet', '-q', '82', framePath(posterFrame), '-o', still], root)
    const kb = (path) => `${Math.round(statSync(path).size / 1024)}KB`
    console.log(` ${out}.webp ${kb(animated)}, ${out}-still.webp ${kb(still)}`)
    if (!keepFrames) rmSync(frames, { recursive: true, force: true })
  }
} finally {
  await browser.close()
  await server.close()
}
