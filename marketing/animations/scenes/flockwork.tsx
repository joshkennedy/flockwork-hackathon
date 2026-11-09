// Flockwork's own pieces, drawn with the app's CSS classes so they follow the app.
// Icons come from ApplicationHelper::ICON_PATHS (generated/icons.json, refreshed by make).
import icons from '../generated/icons.json'

export type IconName = keyof typeof icons

export function Icon({ name, className = '' }: { name: IconName; className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={`fw-icon ${className}`} aria-hidden>
      <path d={icons[name]} />
    </svg>
  )
}

export function Wordmark() {
  return (
    <span className="fw-wordmark">
      <svg viewBox="0.9 5.85 22.2 12.1" aria-hidden>
        <g fill="none" strokeLinecap="round" strokeLinejoin="round">
          <path d="M8.21 10.54 12 7.66l3.79 2.88" stroke="var(--color-mark)" strokeWidth="3.22" />
          <path d="M2.5 16.35 5.8 13.85l3.3 2.5M14.9 16.35l3.3-2.5 3.3 2.5" stroke="var(--color-ink)" strokeWidth="2.8" />
        </g>
      </svg>
      Flockwork
    </span>
  )
}

const initials = (name: string) => name.split(' ').map((part) => part[0]).join('').slice(0, 2)

export function Avatar({ name, hue, size }: { name: string; hue: number; size?: 'sm' | 'lg' }) {
  return <span className={`avatar avatar-person avatar-hue-${hue}${size ? ` avatar-${size}` : ''}`} aria-hidden>{initials(name)}</span>
}

export function PersonPill({ name, hue }: { name: string; hue: number }) {
  return <span className="person-pill"><Avatar name={name} hue={hue} size="sm" /><span>{name}</span></span>
}

const NAV: [IconName, string][] = [['home', 'Home'], ['projects', 'Projects'], ['heart', 'Get involved'], ['people', 'People'], ['oversight', 'Oversight'], ['notifications', 'Notifications']]

/** The app's sidebar: church name, then the nav in DESIGN.md's order. */
export function Sidebar({ active }: { active: string }) {
  return (
    <div className="fw-sidebar">
      <Wordmark />
      <div className="fw-church"><span className="avatar sm">GF</span>Grace Fellowship</div>
      <nav>
        {NAV.map(([icon, label]) => (
          <span key={label} className="nav-item" aria-current={label === active ? 'page' : undefined}><Icon name={icon} />{label}</span>
        ))}
      </nav>
    </div>
  )
}


/**
 * The colored ground a callout scene sits on: soft blurred color fields, a halftone dot texture
 * and fine grain, inside the stage's rounded corners. `tone` picks a palette from the app's own
 * tool and avatar colors. Only the hero and the callouts get one; the rest sit on the page.
 */
export type PlateTone = 'sunrise' | 'meadow' | 'lake' | 'clay' | 'dusk'
export function Plate({ tone = 'sunrise' }: { tone?: PlateTone }) {
  return (
    <div className={`fw-plate fw-plate--${tone}`} aria-hidden>
      <span className="fw-plate__c" />
      <span className="fw-plate__dots" />
      <svg className="fw-plate__grain"><filter id="fw-grain"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" stitchTiles="stitch" /><feColorMatrix values="0 0 0 0 .1 0 0 0 0 .08 0 0 0 0 .06 0 0 0 .22 0" /></filter><rect width="100%" height="100%" filter="url(#fw-grain)" /></svg>
    </div>
  )
}
