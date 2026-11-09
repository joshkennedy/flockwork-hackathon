import { Collapse, Stage, type Act } from '../kit'
import { Icon, PersonPill } from './flockwork'
import { ToolHead, TourWindow } from './tour-shared'
import './tour-tasks.css'

// Tasks: Ana picks up "Set up welcome table" (Unassigned becomes her name), then the
// Leader checks off "Prepare classroom supply bins": the ring fills sunlit and the task
// moves down to Done. The reset reopens it and the assignment leaves, one at a time.

type S = { assigned: boolean; checked: boolean; moved: boolean }
const START: S = { assigned: false, checked: false, moved: false }
const SAM = { name: 'Sam Chen', hue: 1 }
const ANA = { name: 'Ana Torres', hue: 5 }

const script = async (a: Act<S>) => {
  await a.wait(1000)
  a.put({ assigned: true })
  await a.wait(1100)
  await a.click('ring')
  a.put({ checked: true })
  // Off the list, so the cursor never rests on the ring that slides up under it
  void a.move({ x: 760, y: 470 })
  await a.wait(650)
  a.put({ moved: true })
  await a.wait(2600)
  a.put({ moved: false })
  await a.wait(500)
  a.put({ checked: false, assigned: false })
  // Back to where it rested at the start, so the loop meets its first frame
  await a.move({ x: 900, y: 420 })
  await a.wait(300)
}

const Ring = ({ done, target }: { done?: boolean; target?: string }) => (
  <span className={`task-check${done ? ' task-check-done' : ''}`} data-target={target}><Icon name="check" className="task-check-glyph" /></span>
)

function Open({ title, who, due, ring, done }: { title: string; who: React.ReactNode; due: string; ring?: string; done?: boolean }) {
  return (
    <div className="ftt-task">
      <Ring done={done} target={ring} />
      <div><div className="ftt-title">{title}</div><div className="ft-meta ftt-meta">{who}<span>· {due}</span></div></div>
    </div>
  )
}

export default function TourTasks() {
  return (
    <Stage<S> width={1100} height={560} initial={START} poster={{ assigned: true, checked: true, moved: true }} script={script} cursor={{ at: { x: 900, y: 420 } }} fidelity="realistic" className="fw fw-plated fw-tour-tasks">
      {(s) => (
        <TourWindow tab="tasks">
          <ToolHead icon="tasks" color="text-tool-tasks" title="Tasks" add="Add Task" />
          <Collapse open={!s.moved}>
            <Open title="Prepare classroom supply bins" who={<PersonPill {...SAM} />} due="Due in 7 weeks" ring="ring" done={s.checked} />
          </Collapse>
          <Open title="Set up welcome table" due="Due in 8 weeks" who={
            <span className="ft-swap" data-on={s.assigned || undefined}><span>Unassigned</span><PersonPill {...ANA} /></span>
          } />
          <Open title="Post classroom signs" who="Unassigned" due="Due in 8 weeks" />
          <div className="ftt-done-head">Done</div>
          <Collapse open={s.moved}>
            <div className="ftt-done"><Ring done /><span>Prepare classroom supply bins</span></div>
          </Collapse>
          <div className="ftt-done"><Ring done /><span>Print family check-in sheets</span></div>
        </TourWindow>
      )}
    </Stage>
  )
}

export const meta = { out: 'tour-tasks', seconds: 7.8, poster: 4200 }
