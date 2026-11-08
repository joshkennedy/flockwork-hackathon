import { Stage, Window, type Act } from '../kit'
import { Icon, Plate, Sidebar } from './flockwork'
import './tour-shared.css'
import './tour-planner.css'

// Planner: the first screen of a new Project as /projects/new?planning_kind=other draws it, with the
// one sentence typed and Start Planning ready. Static; the animated storyboard is a later scene.

const script = async (a: Act<Record<string, never>>) => {
  await a.wait(6000)
}

export default function TourPlanner() {
  return (
    <Stage width={1100} height={560} initial={{}} script={script} fidelity="realistic" className="fw fw-plated fw-tour-planner">
      {() => (
        <>
          <Plate tone="dusk" />
          <Window sidebar={<Sidebar active="Projects" />} sidebarWidth={180} className="ft-window">
            <div className="fw-crumbs">Projects <span>/</span> Start a Project</div>
            <div className="ft-body">
              <div className="ft-title fw-display">Start a Project</div>
              <div className="ftp-section">
                <div className="ftp-heading">What are you organizing?</div>
                <div className="ftp-lede">Give the Planner one short sentence. Its first question will build on what you share.</div>
                <div className="ftp-label">Describe it in one sentence</div>
                <div className="field ftp-field">Vacation Bible School, June 8 to 12, about 40 kids</div>
                <span className="btn btn-primary ftp-go">Start Planning</span>
                <div className="ftp-privacy"><Icon name="lock" /><span><span>The planner sees project details.</span><span>It never sees your people.</span></span></div>
              </div>
            </div>
          </Window>
        </>
      )}
    </Stage>
  )
}

export const meta = { out: 'tour-planner', seconds: 6, poster: 2000 }
