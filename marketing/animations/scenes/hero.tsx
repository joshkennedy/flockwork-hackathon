import { Collapse, Count, Phone, Stage, Window, type Act } from '../kit'
import family from '../assets/alvarez-family.jpg'
import { Avatar, Icon, Plate, Sidebar } from './flockwork'
import './hero.css'

// The landing hero, a device pair telling one event across a whole church: the Admin's
// Home lists every active Project (a meal train, VBS, a workday, a retreat), and Ruth,
// on her phone in the meal train, taps "I Can Bring Dinner" for Friday. A beat later
// the meal train's row on Home rolls from 15 to 14 dinners still needing someone and
// "Open spots this week" from 4 to 3. The phone straddles the window's empty right
// margin, never the rows it explains.
//
// Real strings: the greeting, the counts, the four Projects with their dates and needs,
// the phone's project and tile. The loop resets by its additions leaving as one
// reverse stagger.

type S = { claimed: boolean; synced: boolean }
const START: S = { claimed: false, synced: false }
const VOLUNTEER = { name: 'Ruth Bennett', hue: 3 }
const GRACE = { name: 'Grace Kim', hue: 6 }
const MARIA = { name: 'Maria Lopez', hue: 4 }

const script = async (a: Act<S>) => {
  await a.wait(900)
  a.mark('tap')
  await a.click('claim', { x: 0.7, y: 0.55 })
  a.put({ claimed: true })
  await a.wait(800)
  a.mark('sync')
  a.put({ synced: true })
  await a.wait(3200)
  a.mark('reset')
  a.put({ synced: false })
  await a.wait(220)
  a.put({ claimed: false })
  await a.wait(900)
  // The finger lifts away to where it started, so every pass is the same
  await a.move({ x: 1000, y: 600 })
  await a.wait(300)
}

// The row's second line: its Leaders as an avatar stack, then its dates
function Meta({ people, dates }: { people: { name: string; hue: number }[]; dates: string }) {
  return (
    <span className="fh-meta">
      <span className="avatar-stack">{people.map((p) => <Avatar key={p.name} {...p} size="sm" />)}</span>
      {dates}
    </span>
  )
}

export default function Hero() {
  return (
    <Stage<S> width={1110} height={640} initial={START} poster={{ claimed: true, synced: true }} script={script} cursor={{ at: { x: 1000, y: 600 }, style: 'touch' }} fidelity="realistic" className="fw fw-plated fw-hero">
      {(s) => (
        <>
          <Plate tone="sunrise" />
          <Window sidebar={<Sidebar active="Home" />} sidebarWidth={180} className="fh-window">
            <div className="fw-crumbs">Home</div>
            <div className="fh-body">
              <div className="fh-title fw-display">Hi Daniel</div>
              <div className="fh-lede">Here’s how Grace Fellowship looks this week.</div>
              <div className="fh-strip">
                <div><span className="fh-k">Active Projects</span><span className="fh-v">5</span></div>
                <div><span className="fh-k">Open spots this week</span><span className="fh-v"><Count value={s.synced ? 3 : 4} duration={600} /></span></div>
                <div><span className="fh-k">People</span><span className="fh-v">60</span></div>
              </div>
              <div className="fh-section">Needs attention</div>
              <div className="fh-sub">Every active Project, the ones short on people first.</div>
              <div className="fh-rows">
                <div className="fh-row">
                  <span className="fh-name">Meal Train for the Alvarez Family<Meta people={[GRACE, MARIA]} dates="Oct 23 – Nov 20" /></span>
                  <span className="badge-need"><Count value={s.synced ? 14 : 15} duration={600} />&nbsp;dinners still need someone</span>
                </div>
                <div className="fh-row">
                  <span className="fh-name">Vacation Bible School 2026<Meta people={[MARIA, { name: 'Elijah Brooks', hue: 8 }]} dates="Dec 28 – Jan 1" /></span>
                  <span className="badge-need">14 spots still open</span>
                </div>
                <div className="fh-row">
                  <span className="fh-name">Church Workday<Meta people={[GRACE, MARIA]} dates="Nov 23" /></span>
                  <span className="badge-need">3 tasks have no one on them</span>
                </div>
                <div className="fh-row">
                  <span className="fh-name">Women’s Fall Retreat<Meta people={[GRACE]} dates="Dec 7 – Dec 9" /></span>
                  <span className="fh-quiet">On track</span>
                </div>
              </div>
            </div>
          </Window>

          <Phone width={330} frame="pro" className="fh-phone">
            <div className="fp-screen">
              <div className="fp-top"><Icon name="menu" /><Avatar {...VOLUNTEER} /></div>
              <img className="fw-banner fp-banner" src={family} alt="" />
              <div className="fp-title fw-display">Meal Train for the Alvarez Family</div>
              <div className="fp-meta">Oct 23 – Nov 20</div>
              <div className="fp-heading">Sign-up sheet</div>
              <div className="fp-tile" data-claimed={s.claimed || undefined}>
                <div className="fp-day">Fri, Nov 6</div>
                <div className="fp-label">Dinner · 6:00 PM</div>
                <Collapse open={!s.claimed}>
                  <div className="fp-open">
                    <span className="badge-need">1 spot left</span>
                    <span className="btn btn-primary fp-claim" data-target="claim">I Can Bring Dinner</span>
                  </div>
                </Collapse>
                <Collapse open={s.claimed}>
                  <div className="fp-done"><Icon name="check" className="text-sunlit" />You’re bringing dinner</div>
                </Collapse>
              </div>
              <div className="fp-tile">
                <div className="fp-day">Sat, Nov 7</div>
                <div className="fp-label">Dinner · 6:00 PM</div>
                <div className="fp-open"><span className="badge-need">1 spot left</span><span className="btn btn-primary fp-claim">I Can Bring Dinner</span></div>
              </div>
            </div>
          </Phone>
        </>
      )}
    </Stage>
  )
}

export const meta = { out: 'hero', seconds: 8, poster: 4300 }
