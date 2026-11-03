import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../../app/assets/builds/tailwind.css'
import './flockwork.css'
import { scenes } from './scenes/manifest'

// ?scene=<name> mounts one scene; with no parameter every scene is listed for a quick look.
const name = new URLSearchParams(location.search).get('scene')
const shown = name ? scenes.filter((scene) => scene.name === name) : scenes
if (name && shown.length === 0) throw new Error(`Unknown scene: ${name}`)

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {shown.map(({ name, Scene }) => <div key={name} id={name} className="scene"><Scene /></div>)}
  </StrictMode>,
)
