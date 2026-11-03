// Every landing page animation, found automatically: each scenes/<name>.tsx exports
// `default` (the Stage) and `meta`: `out` is the file name under app/assets/images/marketing,
// `seconds` is one loop (the recorder checks the last frame meets the first), `poster` the still's moment in ms.
import type { ComponentType } from 'react'

// `offset` (ms) moves where the loop starts, to keep neighbouring scenes out of step.
export type SceneMeta = { out: string; seconds: number; poster: number; offset?: number; scale?: number; quality?: number }
const modules = import.meta.glob<{ default: ComponentType; meta: SceneMeta }>('./*.tsx', { eager: true })

export const scenes = Object.entries(modules)
  .filter(([, module]) => module.meta)
  .map(([path, module]) => ({ name: path.slice(2, -4), Scene: module.default, ...module.meta }))
