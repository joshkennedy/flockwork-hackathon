import { Collapse, Phone, Stage, type Act } from '../kit'
import family from '../assets/alvarez-family.jpg'
import { Icon, Plate, Wordmark, type PlateTone } from './flockwork'
import './card-shared.css'
import './card-signup.css'

// "Anyone can pick a spot": the meal train's shared sign-up page on a phone, pinned from the
// top and running off the bottom. A tap on Monday's button and the tile settles to "You're
// bringing dinner" with the sunlit check; then it lets the spot go again (reverse of the claim).
// Real strings: the title, its description and dates, Sign-up, Monday's and Tuesday's tiles.

type S = { claimed: boolean }

// The finger rests near the stage's bottom-right corner between taps
const restFor = (width: number, height: number) => ({ x: width - 56, y: height - 30 })

const scriptFor = (rest: { x: number; y: number }) => async (a: Act<S>) => {
  await a.wait(1000)
  await a.click('claim', { x: 0.7, y: 0.55 })
  a.put({ claimed: true })
  await a.wait(2900)
  a.put({ claimed: false })
  await a.wait(1600)
  // Back to the rest point, so every pass of the loop starts from the same place
  await a.move(rest)
}

/** The scene at any size: the sign-in page's panel reuses it larger (scenes/auth.tsx). */
export function SignupScene({ width = 456, height = 720, phone = 330, tone = 'sunrise', className = '' }: { width?: number; height?: number; phone?: number; tone?: PlateTone; className?: string }) {
  const rest = restFor(width, height)
  return (
    <Stage<S> width={width} height={height} initial={{ claimed: false }} poster={{ claimed: true }} script={scriptFor(rest)} cursor={{ at: rest, style: 'touch', idle: false }} fidelity="realistic" className={`fw fw-plated fw-cards fw-card-signup ${className}`}>
      {(s) => (
        <>
        <Plate tone={tone} />
        <Phone width={phone} frame="pro" className="cs-phone" style={{ left: (width - phone) / 2 }}>
          <div className="cs-screen">
            <Wordmark />
            <img className="cs-banner" src={family} alt="" />
            <div className="cs-title fw-display">Meal Train for the Alvarez Family</div>
            <div className="cs-lede">Provide a warm dinner each evening while the Alvarez family focuses on recovery.</div>
            <div className="cs-dates">October 23, 2026 to November 20, 2026</div>
            <div className="cs-heading">Sign-up</div>
            <div className="cs-tile" data-claimed={s.claimed || undefined}>
              <div className="cs-when">Monday, November 9<br />6:00 PM</div>
              <div className="cs-label">Dinner</div>
              <Collapse open={!s.claimed}>
                <div className="cs-open">
                  <span className="badge-need">1 spot left</span>
                  <span className="btn btn-primary cs-claim" data-target="claim">I Can Bring Dinner</span>
                </div>
              </Collapse>
              <Collapse open={s.claimed}>
                <div className="cs-done"><Icon name="check" className="text-sunlit" />You’re bringing dinner</div>
              </Collapse>
            </div>
            {/* The next day, as context running off the bottom */}
            <div className="cs-tile cs-next">
              <div className="cs-when">Tuesday, November 10<br />6:00 PM</div>
              <div className="cs-label">Dinner</div>
              <div className="cs-open"><span className="badge-need">1 spot left</span><span className="btn btn-primary cs-claim">I Can Bring Dinner</span></div>
            </div>
          </div>
        </Phone>
        </>
      )}
    </Stage>
  )
}

export default function CardSignup() {
  return <SignupScene />
}

export const meta = { out: 'card-signup', seconds: 7, poster: 3000 }
