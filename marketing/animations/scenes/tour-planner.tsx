import { Stage, Window, type Act } from '../kit'
import { Icon, Plate, Sidebar, type IconName } from './flockwork'
import './tour-shared.css'
import './tour-planner.css'

// Planner: /projects/new?planning_kind=other from one sentence to a project, as the build-as-you-go
// Planner runs it. The sentence types into the field and Start Planning is pressed; three questions
// follow in turn, and each answer resolves more of the preview (Suggestions, not added yet): the
// sign-up sheet, then tasks and the schedule, then the budget. Only the question column swaps; the
// preview stays and fills. Add to Project appears and is pressed. The loop resets by fading back to
// the empty field. Each beat holds long enough to read at the size the landing page shows it.

type S = { text: string; asked: number; answered: number; rows: number; added: boolean }
const START: S = { text: '', asked: 0, answered: 0, rows: 0, added: false }
const SENTENCE = 'Vacation Bible School, June 8 to 12, about 40 kids'
const REST = { x: 940, y: 470 }

// The questions are written the way the Planner's model asks them: one focused question, a few tiles.
const QUESTIONS: { q: string; tiles: string[]; pick: number; rows: number }[] = [
  { q: 'Who is VBS for?', tiles: ['Preschool and kindergarten', 'Kindergarten to 5th grade', 'Kids and teens together', 'Not sure yet'], pick: 1, rows: 1 },
  { q: 'What needs the most hands?', tiles: ['Check-in and pickup', 'Crafts and supplies', 'Snacks each day', 'A bit of everything'], pick: 3, rows: 3 },
  { q: 'Is there a budget to track?', tiles: ['Yes, about $500', 'Yes, not sure how much', 'No budget this year'], pick: 0, rows: 4 },
]

const script = async (a: Act<S>) => {
  await a.wait(300)
  await a.type('text', SENTENCE, { interval: 26 })
  await a.wait(200)
  await a.click('go')
  let rows = 0
  for (const [i, step] of QUESTIONS.entries()) {
    a.put({ asked: i + 1 })
    await a.wait(i === 0 ? 1100 : 900)
    await a.click(`q${i}t${step.pick}`)
    a.put({ answered: i + 1 })
    await a.wait(250)
    await a.stagger(Array.from({ length: step.rows - rows }, (_, k) => rows + k + 1), (n) => a.put({ rows: n }), 420)
    rows = step.rows
    await a.wait(1000)
  }
  a.put({ added: true })
  await a.wait(500)
  await a.click('add')
  await a.wait(1400)
  a.put({ asked: 0, text: '' })
  await a.wait(450)
  await a.snap({ answered: 0, rows: 0, added: false })
  await a.move(REST)
  await a.wait(200)
}

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
    <Stage<S> width={1100} height={560} initial={START} poster={{ text: SENTENCE, asked: 3, answered: 3, rows: 4, added: true }} script={script} cursor={{ at: REST }} fidelity="realistic" className="fw fw-plated fw-tour-planner">
      {(s) => (
        <>
          <Plate />
          <Window sidebar={<Sidebar active="Projects" />} sidebarWidth={180} className="ft-window">
            <div className="fw-crumbs">Projects <span>/</span> Start a Project</div>
            <div className="ft-body ftp-layers">
              <div className="ftp-layer" data-off={s.asked > 0 || undefined}>
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
              <div className="ftp-layer ftp-stage" data-off={s.asked === 0 || undefined}>
                <div className="ftp-ask">
                  <div className="ftp-layers">
                    {QUESTIONS.map((step, qi) => (
                      <div key={step.q} className="ftp-layer" data-off={s.asked !== qi + 1 || undefined}>
                        <div className="ftp-q">{step.q}</div>
                        <div className="ftp-tiles">
                          {step.tiles.map((t, i) => (
                            <div key={t} className="answer-tile ftp-tile" data-on={(s.answered > qi && i === step.pick) || undefined} data-target={`q${qi}t${i}`}>
                              <span className="ftp-opt">{t}</span><span className="ftp-key">{i + 1}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                  <Privacy />
                </div>
                <div className="ftp-preview">
                  <div className="ftp-phead">
                    <div className="ftp-ptitle">Project preview</div>
                    <div className="ft-swap ftp-psub" data-on={s.answered > 0 || undefined}>
                      <span>Your Project will take shape here</span>
                      <span>Suggestions · not added yet</span>
                    </div>
                  </div>
                  <div className="ftp-pbody" data-on={s.answered > 0 || undefined}>
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
                  <span className="btn btn-primary ftp-add" data-on={s.added || undefined} data-target="add">Add to Project</span>
                </div>
              </div>
            </div>
          </Window>
        </>
      )}
    </Stage>
  )
}

export const meta = { out: 'tour-planner', seconds: 16, poster: 13000 }
