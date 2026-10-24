# The "web" image: Caddy with the built frontend and the Caddyfile.
# Build context is the repository root, and frontend/dist must exist first
# (`pnpm build` in frontend/). ./scripts/prod-local.sh does both, and so does the Images job in CI.
#
#   docker build -f infra/web.Dockerfile -t ghcr.io/moonhowl-dev/selenly-web:local .
#
# Only the files listed in web.Dockerfile.dockerignore are sent to Docker.
FROM caddy:2.11.7

COPY infra/Caddyfile /etc/caddy/Caddyfile
COPY frontend/dist /srv
