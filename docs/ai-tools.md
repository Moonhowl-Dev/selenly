# AI tools

AI works in three places in this project: a coding agent in the repository ([Claude Code](https://code.claude.com/docs)), a reviewer on every pull request ([CodeRabbit](https://docs.coderabbit.ai)), and shared rule files that both of them read. The main rule: people write the core of the domain, AI speeds up the rest and checks everything.

| File | Read by | Purpose |
|---|---|---|
| [`CLAUDE.md`](../CLAUDE.md), [`backend/CLAUDE.md`](../backend/CLAUDE.md), [`frontend/CLAUDE.md`](../frontend/CLAUDE.md) | Claude Code, CodeRabbit | stack, commands and rules of the project |
| [`.coderabbit.yaml`](../.coderabbit.yaml) | CodeRabbit | review settings and extra checks for specific paths |
| [`.mcp.json`](../.mcp.json) | Claude Code | MCP servers shared by the team |
| [`infra/dbhub.toml`](../infra/dbhub.toml), [`infra/postgres/init/`](../infra/postgres/init/) | the `db` MCP server | read-only access to the local database |
| `CLAUDE.local.md` (ignored by Git) | Claude Code | your personal instructions, for example "answer in Polish" |

## CLAUDE.md

- Claude Code reads the root `CLAUDE.md` when a session starts, and `backend/CLAUDE.md` or `frontend/CLAUDE.md` the first time it works on a file in that folder. CodeRabbit applies each file to its own folder.
- They hold facts and rules that matter in every session: commands, structure, conventions. Multi-step procedures (for example "add a Spring Modulith module") go into skills in `.claude/skills/<name>/SKILL.md`, which load only when needed.
- Keep each file under about 200 lines: a long file costs context in every session and is followed less reliably.
- Add a rule when the agent makes the same mistake twice, or when a review catches something the agent should have known. Write it so it can be checked ("run `pnpm lint`", not "write clean code").
- To see which files a session loaded, run `/context` in Claude Code and look under **Memory files**.

## CodeRabbit

### Setup (once, by an organization owner)

1. Sign in at [coderabbit.ai](https://coderabbit.ai) with **Login with GitHub** and authorize the `coderabbitai` app.
2. Choose the `Moonhowl-Dev` organization and give it access to the `selenly` repository only.

CodeRabbit is free for public open-source repositories. It reads `.coderabbit.yaml` from the branch of each pull request.

### On every pull request

- A summary and walkthrough of the changes, a sequence diagram when the flow changes, and comments on specific lines.
- Linters on the changed files, among them PMD (Java), Squawk (migrations), actionlint and zizmor (workflows) and Gitleaks (secrets).
- Pre-merge checks for the title (Conventional Commits), the description (the pull request template) and the linked issue. They only warn.

Answer every comment: fix the code, or reply why not. CodeRabbit is a reviewer, not an oracle. Then resolve the thread: the `main` ruleset blocks merging while any review thread is unresolved. When CodeRabbit is wrong about a project convention, explain the convention in the thread: it saves it as a "learning" and applies it in later reviews.

| Comment on the pull request | Effect |
|---|---|
| `@coderabbitai review` | reviews the new commits (normally automatic) |
| `@coderabbitai full review` | reviews the whole pull request again |
| `@coderabbitai pause` / `@coderabbitai resume` | stops or restarts automatic reviews on this pull request |
| `@coderabbitai resolve` | resolves all CodeRabbit comments (only after you have dealt with them) |
| `@coderabbitai configuration` | shows the settings in use and where each one comes from |
| `@coderabbitai help` | lists all commands |

## MCP servers

MCP servers give the agent tools from outside the repository. Each one takes context and is code you trust, so the list stays short.

| Server | Used for | Needs |
|---|---|---|
| `context7` | current documentation of Spring Boot 4, React 19, TanStack and others, so the agent stops suggesting old APIs | internet |
| `db` | the schema and read-only SQL queries on the local database | the database running (`bootRun` or the Compose services) |
| `playwright` | the agent clicks through the running app in a headless browser | `pnpm dev`, and the browser installed (below) |
| `shadcn` | searching shadcn/ui components and the command to add one | `pnpm install` in `frontend/` |

The `db` server connects as the `readonly` role, which can read every table and change nothing. A second guard in `infra/dbhub.toml` rejects any statement other than reading, and results are cut at 200 rows.

### Setup

1. Install the browser for the `playwright` server, in the version that server uses (it asks for your `sudo` password to install system libraries):

   ```bash
   pnpm dlx @playwright/mcp@0.0.83 install-browser chromium --with-deps
   ```

   This is not the same as `npx playwright install`: the browser must match the Playwright version inside `@playwright/mcp`. Run it again whenever that version changes in `.mcp.json`.

2. Create the read-only database role. A new database volume gets it automatically. If your database existed before, run this once from the repository root, with the database running:

   ```bash
   docker compose -f infra/compose.dev.yml exec -T postgres psql -U selenly -d selenly < infra/postgres/init/10-readonly-role.sql
   ```

3. Install the frontend dependencies (`pnpm install` in `frontend/`), because the `shadcn` server is the shadcn CLI from the project.

4. Start `claude` in the **repository root**: the paths in `.mcp.json` are relative to it. On the first start Claude Code asks whether to use the servers from `.mcp.json`; approve them. Then `/mcp` should list all four as connected.

### Why `pnpm dlx` and exact versions

`pnpm dlx` downloads a package and runs it, like `npx`, but with the supply-chain rules pnpm also applies to the frontend:

- It skips versions published less than a day ago, both for the package and for all its dependencies. A compromised package on npm is often discovered and removed within hours, so a day of delay protects against many of these attacks.
- Install scripts of the dependencies do not run. Without a terminal to approve them, which is how Claude Code starts the servers, they stay skipped.
- The package that `pnpm dlx` runs is an exception: its own install script is allowed by default. Running the package executes its code anyway, so for the package itself the protection is the exact, checked version. The versions in `.mcp.json` have no install scripts; before raising one, check with `npm view <package>@<version> scripts` (look for `preinstall`, `install` or `postinstall`).

The exact versions (`@1.5.0`, not `@latest`) mean everyone runs the same code until someone deliberately updates it.

### Personal servers and overrides

Servers with tokens never go into `.mcp.json`. Add them for yourself only; the default scope `local` stores them in `~/.claude.json` for this project. A local server with the same name replaces the shared one completely.

```bash
# GitHub: issues, pull requests and review comments (the gh CLI is often enough)
claude mcp add --transport http github https://api.githubcopilot.com/mcp/ \
  --header "Authorization: Bearer <your GitHub token>"

# Context7 with a free API key from context7.com/dashboard (higher rate limits)
claude mcp add --transport http context7 https://mcp.context7.com/mcp \
  --header "Authorization: Bearer <your Context7 key>"

# Playwright with a visible browser window, to watch what the agent does (needs WSLg)
claude mcp add playwright -- pnpm dlx @playwright/mcp@0.0.83 --browser chromium --isolated
```

`claude mcp list` shows all servers and their status; `claude mcp remove <name>` removes your local one, and the shared server from `.mcp.json` is used again.

## Working with AI

- Write the core yourself: the free-slot algorithm, the booking flow and the Spring Security configuration. AI reviews them and answers "why" questions.
- Hand over repetitive code freely: DTOs, mappings, admin CRUD, forms, CI configuration.
- If you cannot explain a generated line, ask for an explanation, not for a new version.
- Keep pull requests small: a few hundred changed lines is where you and CodeRabbit still read the diff carefully.
- No secrets in prompts. `.env` files are ignored by Git, and CodeRabbit's Gitleaks is a second line of defense.
- Note in the pull request description what AI did and where it was wrong.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Claude Code does not ask about the servers, or `/mcp` does not list them | start `claude` in the repository root. If you rejected them earlier: `claude mcp reset-project-choices` and start again |
| A server fails on the very first start | `pnpm dlx` was still downloading it: reconnect it in `/mcp`, or start with `MCP_TIMEOUT=60000 claude` |
| `db`: `Source 'selenly' is unreachable` | the database is not running: `./gradlew bootRun` in `backend/`, or `docker compose -f infra/compose.dev.yml up -d postgres` |
| `db`: `password authentication failed for user "readonly"` | the role does not exist yet: step 2 of the setup |
| `playwright`: `Executable doesn't exist` | the browser is missing or has a different version: step 1 of the setup |
| `shadcn` fails to start | `pnpm install` in `frontend/` |
