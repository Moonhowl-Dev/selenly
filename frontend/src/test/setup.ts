// Runs before every test file (vite.config.ts → test.setupFiles).
import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'

// Unmount what a test rendered, so the next test starts with an empty page.
afterEach(() => {
  cleanup()
})

// jsdom has no scrolling. The router restores the scroll position after navigation,
// so give it a no-op instead of a "Not implemented" warning in every test.
window.scrollTo = () => {}
