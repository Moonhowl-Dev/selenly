import { createRootRouteWithContext, Link, Outlet } from '@tanstack/react-router'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { TanStackRouterDevtools } from '@tanstack/react-router-devtools'

import type { RouterContext } from '@/app/router'

// The root route wraps every page: shared layout, the "not found" page and,
// in development only, the TanStack devtools (they render nothing in a production build).
export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootLayout,
  notFoundComponent: NotFound,
})

function RootLayout() {
  return (
    <div className="flex min-h-dvh flex-col bg-background text-foreground">
      <header className="border-b">
        <div className="mx-auto flex max-w-5xl items-center px-4 py-3">
          <Link to="/" className="text-lg font-semibold">
            Selenly
          </Link>
        </div>
      </header>
      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-8">
        <Outlet />
      </main>
      <TanStackRouterDevtools position="bottom-right" />
      <ReactQueryDevtools buttonPosition="bottom-left" />
    </div>
  )
}

function NotFound() {
  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-semibold">Nie znaleziono strony</h1>
      <p className="text-muted-foreground">Ten adres nie istnieje albo został zmieniony.</p>
      <Link to="/" className="underline underline-offset-4">
        Wróć na stronę główną
      </Link>
    </section>
  )
}
