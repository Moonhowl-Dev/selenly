# Infrastructure

Docker Compose files and the configuration of the services the application needs.

| File | Purpose | Status |
|---|---|---|
| [`compose.dev.yml`](compose.dev.yml) | PostgreSQL, Keycloak and Mailpit for local development | ready |
| [`postgres/init/`](postgres/init/) | SQL run when the development database is created: the `readonly` role | ready |
| [`dbhub.toml`](dbhub.toml) | the database MCP server for coding agents ([docs/ai-tools.md](../docs/ai-tools.md)) | ready |
| `keycloak/realm.json` | Keycloak realm, OIDC client and test accounts | M1 |
| [`compose.prod.yml`](compose.prod.yml) | the production stack: Caddy, backend, Keycloak and PostgreSQL | ready |
| [`Caddyfile`](Caddyfile) | HTTPS, the built frontend, `/api` and sign-in paths to the backend, the `auth.` subdomain to Keycloak | ready |
| [`web.Dockerfile`](web.Dockerfile) | the `web` image: Caddy with the built frontend and the Caddyfile | ready |
| [`postgres/prod-init/`](postgres/prod-init/) | run when the production database is created: Keycloak's own database and login | ready |
| [`.env.example`](.env.example) | the variables `compose.prod.yml` needs on a server (copied to `.env`) | ready |
| [`compose.prod.local.yml`](compose.prod.local.yml), [`prod-local.env`](prod-local.env) | changes and values for running the production stack on your computer | ready |

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

## Production stack locally

The production stack runs the same way as on a server: the backend as a container image, Keycloak in production mode, the built frontend behind Caddy, and HTTPS everywhere. Trying it locally shows problems that `bootRun` and `pnpm dev` never show: a missing environment variable, a broken image, a redirect to `http://`, a stack that does not fit into 4 GB.

[`scripts/prod-local.sh`](../scripts/prod-local.sh) builds both images from your working copy and starts the stack. Docker must be running, and ports 80 and 443 on your computer must be free.

```bash
./scripts/prod-local.sh
```

The first run takes several minutes: `bootBuildImage` downloads the buildpacks and a JRE, and Keycloak prepares its database. Then:

| Address | What you see |
|---|---|
| <https://selenly.localhost> | the application |
| <https://selenly.localhost/api/anything> | a 404 from Spring Boot, which proves Caddy forwards `/api` to the backend |
| <https://auth.selenly.localhost> | Keycloak; the admin console logs in with `admin` / `admin` |

Browsers send every `*.localhost` name to your own computer, and Caddy gives such names certificates from its own local certificate authority. The browser does not know that authority yet and shows a warning. You can continue past it, or trust the authority once (needed later for signing in, M1):

1. Copy the authority's certificate out of the container into your home folder and open that folder in Windows Explorer:

   ```bash
   ./scripts/prod-local.sh cp web:/data/caddy/pki/authorities/local/root.crt ~/caddy-local-root.crt
   explorer.exe ~
   ```

2. Double-click `caddy-local-root.crt` and choose **Install Certificate → Current User → Place all certificates in the following store → Trusted Root Certification Authorities**, then confirm the security warning.
3. Restart the browser. Remove the certificate again (`certmgr.msc`, the same store) when you no longer need it; `down -v` creates a new authority, which has to be trusted again.

| Command | What it does |
|---|---|
| `./scripts/prod-local.sh` | rebuilds the images from your current code and updates the running stack |
| `./scripts/prod-local.sh ps` | containers and their health |
| `./scripts/prod-local.sh logs` | follows the logs of all services (`logs keycloak` for one) |
| `docker stats --no-stream` | memory use of each container against its limit |
| `./scripts/prod-local.sh down` | stops and removes the containers; the data stays in volumes |
| `./scripts/prod-local.sh down -v` | removes the data too, including Caddy's local authority |

The local stack is a separate Compose project (`selenly-prod-local`), so it can run next to `compose.dev.yml` without touching its data. Its passwords in [`prod-local.env`](prod-local.env) are public development values.

On a server the stack uses `compose.prod.yml` alone, with an `infra/.env` made from [`.env.example`](.env.example) and the images that CI publishes (#10).

### Published images

After every merge to `main` and every Monday, the **Images** job of [CI](../.github/workflows/ci.yml) builds both images from `main` and pushes them to GitHub Container Registry:

| Image | Built with |
|---|---|
| `ghcr.io/moonhowl-dev/selenly-backend` | `./gradlew bootBuildImage` in `backend/` |
| `ghcr.io/moonhowl-dev/selenly-web` | `pnpm build` in `frontend/`, then [`web.Dockerfile`](web.Dockerfile) |

Both get the same tag: the build date, the commit, and the ID and attempt of the CI run, for example `20261024-ecf1eaa-18734567890-1`. The tag is `IMAGE_TAG` in `infra/.env`; the job's summary on the Actions tab shows it after each run. Every build gets a new tag, even a re-run or the weekly rebuild of the same commit, so a tag always points to the same image, and an older tag is a ready rollback.

New packages on GitHub are private. Once, after the first run, make both public so a server can pull them without a token: **Packages** on the organization page → the package → **Package settings** → **Change visibility** → **Public**.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `prod-local.sh`: `Bind for 127.0.0.1:443 failed: port is already allocated` | another program or container uses port 80 or 443 | `docker ps` for containers; in PowerShell `netstat -ano \| findstr :443` shows the process ID of other programs |
| `prod-local.sh`: `bootBuildImage` fails to connect to Docker | Docker Desktop is closed | start Docker Desktop and run the script again |
| `pull access denied for selenly-backend` | `docker compose` was run without the script, so the backend image was never built | use `./scripts/prod-local.sh` |
| The browser cannot find `selenly.localhost` | the browser does not send `*.localhost` to your computer | use a current Chrome, Edge or Firefox, or add `127.0.0.1 selenly.localhost auth.selenly.localhost` to `C:\Windows\System32\drivers\etc\hosts` |
| `prod-local.sh` waits and then reports Keycloak as unhealthy | Keycloak's first start in production mode takes longer, or its database login failed | `./scripts/prod-local.sh logs keycloak` |
| `bootRun` fails with a message that Docker is not running | Docker Desktop is closed, or Docker Engine is stopped | start Docker Desktop (or `sudo systemctl start docker`) |
| `port is already allocated` or `address already in use` | another container or program uses the same port, e.g. a Postgres from another project | `docker ps` to find it, `docker stop <name>`; or change the left-hand port in `compose.dev.yml` |
| The first `bootRun` seems stuck | the images are being downloaded (several hundred MB) | wait, or run the `pull` command above first to see the progress |
| `bootRun` waits and then reports that Keycloak is unhealthy | Keycloak needs more time on a slow machine, or its health check fails | `docker compose -f infra/compose.dev.yml logs keycloak` and look for errors |
| Containers start, but the backend cannot connect to them | the `127.0.0.1` port binding is not visible from WSL in your Docker setup | remove `127.0.0.1:` from the `ports` entries and report it in an issue |
| Containers still run after stopping `bootRun` | the application did not shut down cleanly | harmless: the next `bootRun` reuses them; or run the `stop` command above |
