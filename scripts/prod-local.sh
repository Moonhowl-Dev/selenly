#!/usr/bin/env bash
# Runs the production stack (infra/compose.prod.yml) on this computer, built from your
# working copy: Caddy with HTTPS, the built frontend, the backend image, Keycloak in
# production mode and PostgreSQL. Details: infra/README.md, "Production stack locally".
#
#   ./scripts/prod-local.sh           build the images, then start or update the stack
#   ./scripts/prod-local.sh logs      follow the logs of all services (Ctrl+C stops following)
#   ./scripts/prod-local.sh down      stop and remove the containers; the data volumes stay
#   ./scripts/prod-local.sh down -v   the same, and delete the data too (a full reset)
#   ./scripts/prod-local.sh ps        any other docker compose command, e.g. ps
set -euo pipefail
cd "$(dirname "$0")/.."

compose() {
  docker compose \
    -f infra/compose.prod.yml \
    -f infra/compose.prod.local.yml \
    --env-file infra/prod-local.env \
    "$@"
}

case "${1:-up}" in
  up)
    echo "==> Backend image (the first build downloads the buildpacks, several hundred MB)"
    (cd backend && ./gradlew bootBuildImage --imageName=ghcr.io/moonhowl-dev/selenly-backend:local)

    echo "==> Frontend build"
    (cd frontend && pnpm install --frozen-lockfile && pnpm build)

    echo "==> Starting the stack (Keycloak needs a minute or two on the first start)"
    compose up --detach --build --wait

    cat <<'MSG'

Ready:
  https://selenly.localhost        the application
  https://auth.selenly.localhost   Keycloak (admin / admin)
The browser warns about the certificate until you trust Caddy's local authority
(infra/README.md). Stop the stack with: ./scripts/prod-local.sh down
MSG
    ;;
  logs)
    compose logs --follow
    ;;
  *)
    compose "$@"
    ;;
esac
