import { Count, Stage, type Act } from '../kit'
import { ToolHead, TourWindow } from './tour-shared'
import './tour-budget.css'

// Budget: the craft supplies receipt comes in, "Act. Pending" becomes $398.40, and a beat
// later the Purchases group and the Actual total roll up from $0.00 to match.

type S = { spent: boolean; rolled: boolean }
const money = (n: number) => `$${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

const script = async (a: Act<S>) => {
  await a.wait(1400)
  a.put({ spent: true })
  await a.wait(600)
  a.put({ rolled: true })
  await a.wait(3200)
  a.put({ rolled: false })
  await a.wait(300)
  a.put({ spent: false })
  await a.wait(1300)
}

function Line({ title, est, children }: { title: string; est: string; children?: React.ReactNode }) {
  return (
    <div className="ftb-line">
      <div className="ftb-title">{title}</div>
      <div className="ft-meta">Est. {est} · Act. {children ?? 'Pending'}</div>
    </div>
  )
}

export default function TourBudget() {
  return (
    <Stage<S> width={920} height={520} initial={{ spent: false, rolled: false }} poster={{ spent: true, rolled: true }} script={script} fidelity="realistic" className="fw fw-plated fw-tour-budget">
      {(s) => {
        const actual = s.rolled ? 398.4 : 0
        return (
          <TourWindow tab="budget">
            <ToolHead icon="budget" color="text-tool-budget" title="Budget" add="Add Purchase" />
            <div className="ftb-totals">
              <div><div className="ft-meta">Estimated total</div><div className="ftb-total">$1,825.00</div></div>
              <div><div className="ft-meta">Actual total</div><div className="ftb-total"><Count value={actual} format={money} duration={700} /></div></div>
            </div>
            <div className="ftb-group"><span>Bookings</span><span className="ft-meta">Est. $850.00 · Act. $0.00</span></div>
            <Line title="Inflatable obstacle course" est="$850.00" />
            <div className="ftb-group"><span>Purchases</span><span className="ft-meta">Est. $975.00 · Act. <Count value={actual} format={money} duration={700} /></span></div>
            <div className="ftb-focus" data-on={s.spent || undefined}>
              <Line title="Craft supplies" est="$420.00"><span className="ft-swap" data-on={s.spent || undefined}><span>Pending</span><span className="ftb-paid">$398.40</span></span></Line>
            </div>
            <Line title="Snacks and drinks" est="$315.00" />
            <Line title="Printed curriculum" est="$240.00" />
          </TourWindow>
        )
      }}
    </Stage>
  )
}

export const meta = { out: 'tour-budget', seconds: 6.8, poster: 4200 }
