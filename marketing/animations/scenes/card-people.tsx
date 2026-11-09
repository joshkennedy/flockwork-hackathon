import { Stage, type Act } from '../kit'
import { Avatar, Plate } from './flockwork'
import './card-shared.css'
import './card-people.css'

// "Know your people": the People directory's quick filters. The pointer picks "Not yet asked",
// the underline slides to it, and the rows crossfade to people nobody has asked yet, each with
// the sunlit "Never asked" chip. It goes back by the same click on "Everyone", a seen cause.
// Real strings: the filters with their counts, three names per list and their one meta line.

type S = { filter: 0 | 3 }
const TABS = ['Everyone 60', 'Serving now 35', 'Leaders 5', 'Not yet asked 12']
const EVERYONE = [
  { name: 'Aaron Price', hue: 6, meta: 'Serving on Meal Train for the Alvarez Family' },
  { name: 'Abigail Turner', hue: 0, meta: 'Not serving on an Active Project right now' },
  { name: 'Aisha Johnson', hue: 2, meta: 'Serving on Vacation Bible School 2026' },
]
const NEVER_ASKED = [
  { name: 'Claire Robinson', hue: 3 },
  { name: 'Felicia Cox', hue: 7 },
  { name: 'George Ward', hue: 9 },
]

const script = async (a: Act<S>) => {
  await a.wait(1200)
  await a.click('tab-3')
  a.put({ filter: 3 })
  await a.move({ x: 560, y: 250 })
  await a.wait(2200)
  await a.click('tab-0')
  a.put({ filter: 0 })
  await a.move({ x: 560, y: 250 })
  await a.wait(800)
}

export default function CardPeople() {
  return (
    <Stage<S> width={640} height={280} initial={{ filter: 0 }} poster={{ filter: 3 }} script={script} cursor={{ at: { x: 560, y: 250 }, idle: false }} fidelity="realistic" className="fw fw-plated fw-cards fw-card-people">
      {(s, rect) => {
        const bar = rect('tabs')
        const on = rect(`tab-${s.filter}`)
        return (
          <>
          <Plate />
          <div className="fc-panel cp-panel">
            <div className="tab-bar cp-tabs" data-target="tabs">
              {TABS.map((tab, i) => {
                const [label, count] = [tab.slice(0, tab.lastIndexOf(' ')), tab.slice(tab.lastIndexOf(' ') + 1)]
                return <span key={tab} className="tab-link cp-tab" data-target={`tab-${i}`} data-on={s.filter === i || undefined}>{label}<span className="cp-count">{count}</span></span>
              })}
              {on.width > 0 && <span className="cp-underline" style={{ left: on.x - bar.x, width: on.width }} />}
            </div>
            <div className="cp-lists">
              <div className="cp-list" data-shown={s.filter === 0 || undefined}>
                {EVERYONE.map((p, i) => (
                  <div key={p.name} className="cp-row fc-ease" style={{ transitionDelay: s.filter === 0 ? `${120 + i * 60}ms` : `${i * 40}ms` }}>
                    <Avatar name={p.name} hue={p.hue} />
                    <div><div className="fc-name">{p.name}</div><div className="fc-meta">{p.meta}</div></div>
                  </div>
                ))}
              </div>
              <div className="cp-list" data-shown={s.filter === 3 || undefined}>
                {NEVER_ASKED.map((p, i) => (
                  <div key={p.name} className="cp-row fc-ease" style={{ transitionDelay: s.filter === 3 ? `${120 + i * 60}ms` : `${i * 40}ms` }}>
                    <Avatar name={p.name} hue={p.hue} />
                    <div><div className="fc-name">{p.name} <span className="status-chip status-chip-need">Never asked</span></div><div className="fc-meta">Not serving on an Active Project right now</div></div>
                  </div>
                ))}
              </div>
            </div>
          </div>
          </>
        )
      }}
    </Stage>
  )
}

export const meta = { out: 'card-people', seconds: 7, poster: 3600, offset: 2300 }
