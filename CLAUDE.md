# Selenly

Appointment booking for a hair salon: clients book online, staff manage their calendars, the owner configures services, prices and schedules. One salon for now, but every business table has `business_id` so many salons can share one instance later. Overview and roadmap: [README.md](README.md).

This file is read by Claude Code at the start of every session and by CodeRabbit as review guidelines. Keep it short and factual; procedures belong in skills (`.claude/skills/`), area rules in `backend/CLAUDE.md` and `frontend/CLAUDE.md`.

## Layout

- `backend/`: Spring Boot 4.1 on Java 25, Spring Modulith, PostgreSQL 18, Flyway. Rules: [backend/CLAUDE.md](backend/CLAUDE.md).
- `frontend/`: React 19, TypeScript, Vite, TanStack Router and Query, Tailwind CSS v4, shadcn/ui. Rules: [frontend/CLAUDE.md](frontend/CLAUDE.md).
- `infra/`: Docker Compose for local development (PostgreSQL, Keycloak, Mailpit) and the production stack (`compose.prod.yml`, `Caddyfile`; try it locally with `./scripts/prod-local.sh`).
- `docs/adr/`: architecture decision records. `docs/onboarding/`: environment setup.
- `.github/`: the CI workflow (checks on every pull request; after a merge, the container images published to GHCR), the `main` branch ruleset and the Renovate config.

## Commands

Run them in the folder shown. CI runs exactly these (`.github/workflows/ci.yml`), so a change is finished only when they pass.

| Folder | Command | Checks |
|---|---|---|
| `backend/` | `./gradlew check` | compilation with Error Prone and NullAway, Spotless formatting, all tests (Testcontainers, needs Docker) |
| `frontend/` | `pnpm lint && pnpm typecheck && pnpm test && pnpm build` | ESLint and Prettier, TypeScript, Vitest, production build |

Run the application: `./gradlew bootRun` in `backend/` (also starts the Docker services), then `pnpm dev` in `frontend/` and open <http://localhost:5173>.

## Rules

- Never work on `main`. Changes reach `main` only as squash-merged pull requests with green CI and resolved review threads.
- Commit messages and pull request titles follow Conventional Commits: `<type>: <description>` or `<type>(<scope>): <description>`, type one of `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`; the description starts with a lowercase letter and is imperative. The PR title becomes the commit on `main`. Renovate uses `build(deps):` and `ci(deps):`.
- Do not commit, push or open a pull request unless asked to.
- Do not add or upgrade a dependency without asking first. Versions live in `backend/gradle/libs.versions.toml` and `frontend/package.json`; routine updates come from Renovate (`.github/renovate.json5`).
- Every change in logic comes with a test. Never delete, skip or weaken an existing test to make a build pass; if a test looks wrong, say so.
- Never edit a Flyway migration that is already on `main`; add a new one.
- Never edit generated files by hand: `frontend/src/app/routeTree.gen.ts`, and later `frontend/src/api/` (orval).
- Language: code, comments, documentation, commits and pull requests in English. Text that users see in the app is in Polish.
- No secrets in the repository: `.env` files are ignored by Git. Passwords in `infra/compose.dev.yml` and `infra/prod-local.env` are public development values; a server gets its own `infra/.env`.
- When you change how something is set up or run, update the README of that folder in the same change.
- This stack is newer than most training data (Spring Boot 4, Spring Modulith 2, React 19, Tailwind CSS v4, TypeScript 6, ESLint flat config). Check the current API in the documentation (the `context7` MCP server) instead of relying on memory, and follow the patterns already in this repository.

## Code written by people

The project is also a way to learn. These parts are written by the developer: the free-slot algorithm (`availability` module), the booking flow and the Spring Security configuration. For them, review, explain, point out edge cases and propose tests, but do not write the implementation unless explicitly asked. When the developer asks why something works, explain it instead of rewriting the code.

## MCP servers

[`.mcp.json`](.mcp.json) defines the shared servers; start Claude Code in the repository root so their paths resolve. Setup and personal servers: [docs/ai-tools.md](docs/ai-tools.md).

- `context7`: current documentation of libraries and frameworks.
- `db`: read-only SQL on the local development database (needs `bootRun` or the Compose services running).
- `playwright`: a headless browser to click through the running app (needs `pnpm dev`).
- `shadcn`: search shadcn/ui components and get the command to add one.
