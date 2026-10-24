#!/usr/bin/env bash
# A separate database and login for Keycloak, so its tables never mix with the
# application's and each service can only reach its own data.
#
# PostgreSQL runs the files in /docker-entrypoint-initdb.d only when it creates an
# empty data volume (the first start on a server). The password comes from the
# KEYCLOAK_DB_PASSWORD variable of the postgres service in compose.prod.yml.
set -euo pipefail

# :'kc_password' inserts the variable as a quoted SQL literal, so any character
# in the password is safe.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set kc_password="$KEYCLOAK_DB_PASSWORD" <<'SQL'
CREATE ROLE keycloak LOGIN PASSWORD :'kc_password';
CREATE DATABASE keycloak OWNER keycloak;
SQL
