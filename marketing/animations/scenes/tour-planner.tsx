import { Stage, Window, type Act } from '../kit'
import { Icon, Plate, Sidebar, type IconName } from './flockwork'
import './tour-shared.css'
import './tour-planner.css'

// Planner: /projects/new?planning_kind=other from one sentence to a project. The sentence types
// into the field and Start Planning is pressed; the first question arrives with four answer
// tiles, the second is chosen; the preview (Suggestions, not added yet) fills with dashed
// skeleton rows that resolve one by one; the primary reads "Add to Project". The loop resets by
// crossfading back to the empty field.

type S = { text: string; asked: boolean; chosen: boolean; rows: number; added: boolean }
const START: S = { text: '', asked: false, chosen: false, rows: 0, added: false }
const SENTENCE = 'Vacation Bible School, June 8 to 12, about 40 kids'
const REST = { x: 940, y: 470 }

const script = async (a: Act<S>) => {
  await a.wait(300)
  await a.type('text', SENTENCE, { interval: 26 })
  await a.wait(150)
  await a.click('go')
  a.put({ asked: true })
  await a.wait(600)
  await a.click('tile2')
  a.put({ chosen: true })
  await a.move(REST)
  await a.wait(300)
  await a.stagger([0, 1, 2, 3], (i) => a.put({ rows: i + 1 }), 450)
  await a.wait(500)
  a.put({ added: true })
  await a.wait(900)
  a.put({ asked: false, text: '' })
  await a.wait(450)
  await a.snap({ chosen: false, rows: 0, added: false })
  await a.move(REST)
  await a.wait(200)
}

const TILES = ['Preschool and kindergarten', 'Kindergarten to 5th grade', 'Kids and teens together', 'Not sure yet']
const GROUPS: { icon: IconName; tone: string; label: string; item: string; meta: string }[] = [
  { icon: 'schedule', tone: 'signup', label: 'Sign-up sheet', item: 'Check-in volunteers', meta: 'Mon to Fri, 8:30 AM' },
  { icon: 'tasks', tone: 'tasks', label: 'Tasks', item: 'Order craft supplies', meta: 'Due in 4 weeks' },
  { icon: 'schedule', tone: 'schedule', label: 'Schedule', item: 'VBS week', meta: 'June 8 to 12' },
  { icon: 'budget', tone: 'budget', label: 'Budget', item: 'Snacks and supplies', meta: '$480' },
]

const Privacy = () => (
  <div className="ftp-privacy"><Icon name="lock" /><span><span>The planner sees project details.</span><span>It never sees your people.</span></span></div>
)

export default function TourPlanner() {
  return (
    <Stage<S> width={1100} height={560} initial={START} poster={{ text: SENTENCE, asked: true, chosen: true, rows: 4, added: true }} script={script} cursor={{ at: REST }} fidelity="realistic" className="fw fw-plated fw-tour-planner">
      {(s) => (
        <>
          <Plate tone="dusk" />
          <Window sidebar={<Sidebar active="Projects" />} sidebarWidth={180} className="ft-window">
            <div className="fw-crumbs">Projects <span>/</span> Start a Project</div>
            <div className="ft-body ftp-layers">
              <div className="ftp-layer" data-off={s.asked || undefined}>
                <div className="ft-title fw-display">Start a Project</div>
                <div className="ftp-section">
                  <div className="ftp-heading">What are you organizing?</div>
                  <div className="ftp-lede">Give the Planner one short sentence. Its first question will build on what you share.</div>
                  <div className="ftp-label">Describe it in one sentence</div>
                  <div className="field ftp-field">{s.text}{s.text.length < SENTENCE.length && <span className="ftp-caret" />}</div>
                  <span className="btn btn-primary ftp-go" data-target="go">Start Planning</span>
                  <Privacy />
                </div>
              </div>
              <div className="ftp-layer ftp-stage" data-off={!s.asked || undefined}>
                <div className="ftp-ask">
                  <div className="ftp-q">Who is VBS for?</div>
                  <div className="ftp-tiles">
                    {TILES.map((t, i) => (
                      <div key={t} className="answer-tile ftp-tile" data-on={(s.chosen && i === 1) || undefined} data-target={`tile${i + 1}`}>
                        <span className="ftp-opt">{t}</span><span className="ftp-key">{i + 1}</span>
                      </div>
                    ))}
                  </div>
                  <Privacy />
                </div>
                <div className="ftp-preview">
                  <div className="ftp-phead">
                    <div className="ftp-ptitle">Project preview</div>
                    <div className="ft-swap ftp-psub" data-on={s.chosen || undefined}>
                      <span>Your Project will take shape here</span>
                      <span>Suggestions · not added yet</span>
                    </div>
                  </div>
                  <div className="ftp-pbody" data-on={s.chosen || undefined}>
                  <div className="meal-preview-empty ftp-empty">
                    <p className="font-semibold">Choose what matters first.</p>
                    <p className="ft-meta">Tasks, dates, costs, and lists will stay visible here before anything is added.</p>
                  </div>
                  <div className="planner-tool-groups ftp-groups">
                    {GROUPS.map((g, i) => (
                      <div key={g.label} className="planner-tool-group">
                        <div className="planner-tool-heading"><span className="ftp-gicon" style={{ color: `var(--color-tool-${g.tone})` }}><Icon name={g.icon} /></span><span>{g.label}</span></div>
                        <div className="ftp-slot" data-done={s.rows > i || undefined}>
                          <div className="ftp-skel"><div className="meal-skeleton" /><div className="meal-skeleton meal-skeleton-short" /></div>
                          <div className="ftp-item"><b>{g.item}</b><span>{g.meta}</span></div>
                        </div>
                      </div>
                    ))}
                  </div>
                  </div>
                  <span className="btn btn-primary ftp-add" data-on={s.added || undefined}>Add to Project</span>
                </div>
              </div>
            </div>
          </Window>
        </>
      )}
    </Stage>
  )
}

export const meta = { out: 'tour-planner', seconds: 8, poster: 7300, quality: 45 }
