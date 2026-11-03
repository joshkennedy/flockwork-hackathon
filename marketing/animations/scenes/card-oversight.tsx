import { Bar, Stage, type Act } from '../kit'
import { Avatar, PersonPill, Plate } from './flockwork'
import './card-shared.css'
import './card-oversight.css'

// "Notice who's carrying too much": one Oversight check-in card. Maria serves on four Active
// Projects with no check-in logged; the pointer presses "Log a check-in" and her status line
// swaps to "Checked in today by Daniel Okafor". Plain counts, no scores (DESIGN.md).
// Real strings: Maria's name, the count, her projects, the status line, the button.

type S = { logged: boolean }

const script = async (a: Act<S>) => {
  await a.wait(1400)
  await a.click('log', { x: 0.93, y: 0.7 })
  a.put({ logged: true })
  await a.move({ x: 590, y: 250 })
  await a.wait(2800)
  a.put({ logged: false })
  await a.wait(1800)
}

export default function CardOversight() {
  return (
    <Stage<S> width={640} height={280} initial={{ logged: false }} poster={{ logged: true }} script={script} cursor={{ at: { x: 590, y: 250 }, idle: false }} fidelity="realistic" className="fw fw-plated fw-cards fw-card-oversight">
      {(s) => (
        <>
        <Plate tone="dusk" />
        <div className="fc-panel co-panel">
          <div className="co-label">May need a check-in</div>
          <div className="co-card">
            <div className="co-head">
              <Avatar name="Maria Lopez" hue={4} />
              <div><div className="fc-name">Maria Lopez</div><div className="fc-meta">4 Active Projects</div></div>
              <span className="btn btn-secondary btn-sm co-log" data-target="log">Log a check-in</span>
            </div>
            <div className="co-projects">Church Workday, Meal Train for the Alvarez Family, Vacation Bible School 2026, Women’s Fall Retreat</div>
            <div className="co-status">
              {/* Both lines share one cell and crossfade, so nothing re-measures between passes */}
              <span className="co-swap" data-on={s.logged || undefined}>
                <span className="co-none">No check-in logged yet.</span>
                <span className="co-logged">Checked in today by <PersonPill name="Daniel Okafor" hue={1} /></span>
              </span>
            </div>
          </div>
          {/* The next person in the list, as filler running off the bottom */}
          <div className="co-card co-next">
            <div className="co-head"><span className="avatar avatar-person avatar-hue-6" /><div className="co-bars"><Bar w={96} h={6} tone={3} /><Bar w={120} h={5} tone={2} /></div></div>
          </div>
        </div>
        </>
      )}
    </Stage>
  )
}

export const meta = { out: 'card-oversight', seconds: 7, poster: 4000, offset: 4700 }
