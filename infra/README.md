# Infrastructure

Docker Compose files and the configuration of the services the application needs.

**Nothing here yet.** Planned files:

| File | Purpose | Issue |
|---|---|---|
| `compose.dev.yml` | PostgreSQL, Keycloak and Mailpit for local development, started by `bootRun` | [#4](https://github.com/Moonhowl-Dev/selenly/issues/4) |
| `keycloak/realm.json` | Keycloak realm, OIDC client and test accounts | |
| `compose.prod.yml` | application, PostgreSQL, Keycloak and Caddy on the server | [#11](https://github.com/Moonhowl-Dev/selenly/issues/11) |
| `Caddyfile` | HTTPS, the built frontend, `/api` to the backend, `auth.` subdomain to Keycloak | [#11](https://github.com/Moonhowl-Dev/selenly/issues/11) |

Secrets never go into this folder: on the server they live in a `.env` file, locally in `.env` files ignored by Git.
