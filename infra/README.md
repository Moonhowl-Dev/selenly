# Infrastructure

Docker Compose files and the configuration of the services the application needs.

| File | Purpose | Status |
|---|---|---|
| [`compose.dev.yml`](compose.dev.yml) | PostgreSQL, Keycloak and Mailpit for local development | ready |
| [`postgres/init/`](postgres/init/) | SQL run when the development database is created: the `readonly` role | ready |
| [`dbhub.toml`](dbhub.toml) | the database MCP server for coding agents ([docs/ai-tools.md](../docs/ai-tools.md)) | ready |
| `keycloak/realm.json` | Keycloak realm, OIDC client and test accounts | M1 |
| `compose.prod.yml` | application, PostgreSQL, Keycloak and Caddy on the server | [#11](https://github.com/Moonhowl-Dev/selenly/issues/11) |
| `Caddyfile` | HTTPS, the built frontend, `/api` to the backend, `auth.` subdomain to Keycloak | [#11](https://github.com/Moonhowl-Dev/selenly/issues/11) |

Secrets never go into this folder: on the server they live in a `.env` file, locally in `.env` files ignored by Git.

## Local development

You usually do not start these services yourself: `./gradlew bootRun` in `backend/` starts them and stops them when the application exits. Docker must be running (with Docker Desktop: the app must be open).

| Service | Address on your machine | Login | Used for |
|---|---|---|---|
| PostgreSQL 18 | `localhost:5432`, database `selenly` | `selenly` / `selenly` | the application database |
| Keycloak | <http://localhost:8180/admin> | `admin` / `admin` | sign-in (from M1) |
| Mailpit | <http://localhost:8025> (SMTP on `localhost:1025`) | none | inbox for every email the application sends |

PostgreSQL also has a `readonly` / `readonly` login that can read every table and change nothing, for tools such as the agents' database MCP server. It is created by [`postgres/init/10-readonly-role.sql`](postgres/init/10-readonly-role.sql) when the database volume is created; for an older volume, run the command at the top of that file once.

These passwords are for local development only. All ports are bound to `127.0.0.1`, so the services are not reachable from your network.

Keycloak listens on 8180 because the backend uses 8080. For now it has only the `master` realm; the application realm with test accounts arrives in M1.

## Useful commands

Run them from the repository root.

| Command | What it does |
|---|---|
| `docker compose -f infra/compose.dev.yml pull` | downloads the images (worth doing once before the first `bootRun`) |
| `docker compose -f infra/compose.dev.yml up -d` | starts the services without the backend |
| `docker compose -f infra/compose.dev.yml ps` | shows the containers and their health (`healthy` = ready) |
| `docker compose -f infra/compose.dev.yml logs -f keycloak` | follows one service's logs (`Ctrl+C` to stop) |
| `docker compose -f infra/compose.dev.yml exec postgres psql -U selenly` | opens a SQL console (`\q` to quit) |
| `docker compose -f infra/compose.dev.yml stop` | stops the containers and keeps the data |
| `docker compose -f infra/compose.dev.yml down` | removes the containers; the database stays in a volume, Keycloak starts clean |
| `docker compose -f infra/compose.dev.yml down -v` | removes everything, including the database (a full reset) |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `bootRun` fails with a message that Docker is not running | Docker Desktop is closed, or Docker Engine is stopped | start Docker Desktop (or `sudo systemctl start docker`) |
| `port is already allocated` or `address already in use` | another container or program uses the same port, e.g. a Postgres from another project | `docker ps` to find it, `docker stop <name>`; or change the left-hand port in `compose.dev.yml` |
| The first `bootRun` seems stuck | the images are being downloaded (several hundred MB) | wait, or run the `pull` command above first to see the progress |
| `bootRun` waits and then reports that Keycloak is unhealthy | Keycloak needs more time on a slow machine, or its health check fails | `docker compose -f infra/compose.dev.yml logs keycloak` and look for errors |
| Containers start, but the backend cannot connect to them | the `127.0.0.1` port binding is not visible from WSL in your Docker setup | remove `127.0.0.1:` from the `ports` entries and report it in an issue |
| Containers still run after stopping `bootRun` | the application did not shut down cleanly | harmless: the next `bootRun` reuses them; or run the `stop` command above |
