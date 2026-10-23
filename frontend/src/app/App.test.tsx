import { QueryClient } from '@tanstack/react-query'
import { createMemoryHistory } from '@tanstack/react-router'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { App } from './App'
import { createAppRouter } from './router'

/** Renders the whole app (providers + router) at the given address, without a real browser. */
function renderAt(path: string) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  const router = createAppRouter({
    queryClient,
    history: createMemoryHistory({ initialEntries: [path] }),
  })
  render(<App queryClient={queryClient} router={router} />)
}

describe('App', () => {
  it('shows the home page at /', async () => {
    renderAt('/')

    expect(
      await screen.findByRole('heading', { level: 1, name: 'Zarezerwuj wizytę' }),
    ).toBeInTheDocument()
  })

  it('shows the not-found page for an unknown address', async () => {
    renderAt('/does-not-exist')

    expect(
      await screen.findByRole('heading', { level: 1, name: 'Nie znaleziono strony' }),
    ).toBeInTheDocument()
  })
})
