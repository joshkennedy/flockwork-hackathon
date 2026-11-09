// The frame every tour scene shares: the VBS project open in the app, one tab active. No sidebar,
// crumbs or plate: the window is cropped to the project so its tool reads near 1:1 on the page.
import type { ReactNode } from 'react'
import { Window } from '../kit'
import { Avatar, Icon, type IconName } from './flockwork'
import './tour-shared.css'

const TABS: [string, string][] = [['signup', 'Sign-up sheet'], ['tasks', 'Tasks'], ['schedule', 'Schedule'], ['list', 'List'], ['budget', 'Budget'], ['notes', 'Notes'], ['team', 'Team']]

/** A tool's heading row, as the app draws it: its icon in the tool color, the name, then "Add …". */
export function ToolHead({ icon, color, title, add }: { icon: IconName; color: string; title: string; add: string }) {
  return (
    <div className="ft-head">
      <span className="ft-head-title"><Icon name={icon} className={color} />{title}</span>
      <span className="btn btn-secondary btn-sm"><Icon name="plus" />{add}</span>
    </div>
  )
}

export function TourWindow({ tab, aside = true, children }: { tab: string; aside?: boolean; children: ReactNode }) {
  return (
    <Window className="ft-window">
      <div className="ft-body">
        <div className="tab-bar ft-tabs">
          {TABS.map(([key, label]) => <span key={key} className="tab-link" aria-current={key === tab ? 'true' : undefined}>{label}</span>)}
        </div>
        <div className="ft-columns" data-aside={aside || undefined}>
          <div className="ft-tool">{children}</div>
          {/* The project's side column, as the app shows it beside every tool */}
          {aside && <div className="ft-aside">
            <div className="ft-card"><span className="ft-caret" />Sharing and ownership</div>
            <div className="ft-card ft-team">
              <span>Team</span>
              <span className="avatar-stack"><Avatar name="Maria Lopez" hue={4} /><Avatar name="Elijah Brooks" hue={7} /><Avatar name="Naomi Patel" hue={2} /></span>
              <span className="ft-meta">23 people</span>
            </div>
          </div>}
        </div>
      </div>
    </Window>
  )
}
