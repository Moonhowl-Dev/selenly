import { createRouter, type RouterHistory } from '@tanstack/react-router'
import type { QueryClient } from '@tanstack/react-query'

import { routeTree } from './routeTree.gen'

export interface RouterContext {
  queryClient: QueryClient
}

interface CreateAppRouterOptions extends RouterContext {
  /** Tests pass a memory history; the app uses the browser's address bar (the default). */
  history?: RouterHistory
}

export function createAppRouter({ queryClient, history }: CreateAppRouterOptions) {
  return createRouter({
    routeTree,
    context: { queryClient },
    // Route loaders read data through TanStack Query, so the router itself does not cache it.
    defaultPreloadStaleTime: 0,
    scrollRestoration: true,
    ...(history ? { history } : {}),
  })
}

// Registers the router type, so <Link to="..."> and useParams() are type-checked against the routes.
declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof createAppRouter>
  }
}
