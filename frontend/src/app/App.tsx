import { QueryClientProvider, type QueryClient } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'

import type { createAppRouter } from './router'

interface AppProps {
  queryClient: QueryClient
  router: ReturnType<typeof createAppRouter>
}

/** Providers shared by the browser entry point (main.tsx) and the tests. */
export function App({ queryClient, router }: AppProps) {
  return (
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  )
}
