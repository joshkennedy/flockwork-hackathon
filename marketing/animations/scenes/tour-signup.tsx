import { Count, Stage, type Act } from '../kit'
import { Icon, PersonPill } from './flockwork'
import { ToolHead, TourWindow } from './tour-shared'
import './tour-signup.css'

// Sign-ups, the Leader's view: Ana claims a check-in helper spot on Tuesday from her
// own phone (unseen), and the row takes her name while "3 spots left" rolls to 2.
// Cursorless: this is what the system does. The reset is her claim leaving as one thing.

type S = { claimed: boolean }
const ROWS = [
  { day: 'Mon, Dec 28', left: 2, by: { name: 'Sam Chen', hue: 1 } },
  { day: 'Tue, Dec 29', left: 3, focus: true },
  { day: 'Wed, Dec 30', left: 3 },
  { day: 'Thu, Dec 31', left: 3 },
  { day: 'Fri, Jan 1, 2027', left: 3 },
]

const script = async (a: Act<S>) => {
  await a.wait(1400)
  a.put({ claimed: true })
  await a.wait(3600)
  a.put({ claimed: false })
  await a.wait(1600)
}

export default function TourSignup() {
  return (
    <Stage<S> width={1100} height={560} initial={{ claimed: false }} poster={{ claimed: true }} script={script} fidelity="realistic" className="fw fw-plated fw-tour-signup">
      {(s) => (
        <TourWindow tab="signup" tone="sunrise" aside={false}>
          <ToolHead icon="schedule" color="text-tool-signup" title="Sign-up sheet" add="Add slot" />
          {ROWS.map((row) => {
            const claimed = row.focus && s.claimed
            return (
              <div key={row.day} className="fts-row">
                <span className="fts-day">{row.day}</span>
                <span className="fts-label">Check-in helper <span>· 8:15 AM</span></span>
                <span className="fts-end">
                  {row.by && <span className="fts-claimers"><Icon name="check" className="text-success" /><PersonPill {...row.by} /></span>}
                  {row.focus && (
                    <span className="fts-join" data-on={claimed || undefined}>
                      <span className="fts-claimers"><Icon name="check" className="text-success" /><PersonPill name="Ana Torres" hue={5} /></span>
                    </span>
                  )}
                  <span className="badge-need"><Count value={claimed ? row.left - 1 : row.left} duration={500} />&nbsp;spots left</span>
                  <span className="btn btn-secondary btn-sm">I can help</span>
                </span>
              </div>
            )
          })}
        </TourWindow>
      )}
    </Stage>
  )
}

export const meta = { out: 'tour-signup', seconds: 6.6, poster: 3800 }
