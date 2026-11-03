import { Collapse, Stage, type Act } from '../kit'
import { ToolHead, TourWindow } from './tour-shared'
import './tour-schedule.css'

// Schedule: a snack break lands in Monday's plan in time order, the rows below make
// room, and the new row glows sunlit for a moment. Cursorless; the reset folds it away.

type S = { added: boolean }
const DAYS = [
  { day: 'Monday, December 28', items: [['Volunteer huddle', '8:30 AM · Fellowship Hall'], ['Opening worship', '9:00 AM · Sanctuary']] },
  { day: 'Wednesday, December 30', items: [['Water games', '11:30 AM · East Lawn']] },
  { day: 'Friday, January 1', items: [['Family closing program', '11:45 AM · Sanctuary']] },
]

const script = async (a: Act<S>) => {
  await a.wait(1400)
  a.put({ added: true })
  await a.wait(3800)
  a.put({ added: false })
  await a.wait(1600)
}

const Item = ({ title, meta }: { title: string; meta: string }) => (
  <div className="ftc-item"><div className="ftc-title">{title}</div><div className="ft-meta">{meta}</div></div>
)

export default function TourSchedule() {
  return (
    <Stage<S> width={1100} height={560} initial={{ added: false }} poster={{ added: true }} script={script} fidelity="realistic" className="fw fw-plated fw-tour-schedule">
      {(s) => (
        <TourWindow tab="schedule" tone="meadow">
          <ToolHead icon="schedule" color="text-tool-schedule" title="Schedule" add="Add Item" />
          {DAYS.map(({ day, items }, d) => (
            <div key={day} className="ftc-day">
              <div className="ftc-date">{day}</div>
              {items.map(([title, meta]) => <Item key={title} title={title} meta={meta} />)}
              {d === 0 && (
                <Collapse open={s.added} reveal="drop">
                  <div className="ftc-new" data-on={s.added || undefined}><Item title="Snack break" meta="10:15 AM · Fellowship Hall" /></div>
                </Collapse>
              )}
            </div>
          ))}
        </TourWindow>
      )}
    </Stage>
  )
}

export const meta = { out: 'tour-schedule', seconds: 6.8, poster: 4000 }
