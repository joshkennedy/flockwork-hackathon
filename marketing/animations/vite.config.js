import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// The scenes load the app's compiled Tailwind build, so they live under the repo root's file access.
export default defineConfig({ plugins: [react()], server: { host: '127.0.0.1', fs: { allow: ['../..'] } }, resolve: { dedupe: ['react', 'react-dom'] } })
