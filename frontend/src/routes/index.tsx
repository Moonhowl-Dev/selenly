import { createFileRoute } from '@tanstack/react-router'

import { Button } from '@/shared/ui/button'

// File-based routing: src/routes/index.tsx is the page at "/".
export const Route = createFileRoute('/')({
  component: HomePage,
})

function HomePage() {
  return (
    <section className="space-y-3">
      <h1 className="text-3xl font-semibold tracking-tight">Zarezerwuj wizytę</h1>
      <p className="max-w-prose text-muted-foreground">
        Wkrótce: usługi salonu, wolne terminy i rezerwacja w trzech krokach.
      </p>
      <Button disabled>Rezerwacja online wkrótce</Button>
    </section>
  )
}
