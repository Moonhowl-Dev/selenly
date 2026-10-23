/// <reference types="vitest/config" />
import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import { tanstackRouter } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// Everything the browser sends to these paths goes to Spring Boot,
// so the frontend and the API share one origin (no CORS) in development.
// changeOrigin: false keeps the browser's Host header (localhost:5173). Vite's short
// form ('/api': url) would rewrite it to localhost:8080, and Spring would then build
// sign-in redirects (M1) for the wrong port.
const toBackend = { target: 'http://localhost:8080', changeOrigin: false }

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    // Must come before react(): it generates the route tree from src/routes.
    tanstackRouter({
      target: 'react',
      autoCodeSplitting: true,
      generatedRouteTree: './src/app/routeTree.gen.ts',
    }),
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    // Fail instead of silently moving to 5174: the sign-in redirect (M1) expects 5173.
    strictPort: true,
    proxy: {
      '/api': toBackend,
      '/oauth2': toBackend,
      '/login': toBackend,
      '/logout': toBackend,
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
  },
})
