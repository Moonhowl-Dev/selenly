-- A read-only login for tools that only need to look at the data, such as the
-- database MCP server for coding agents in .mcp.json (see docs/ai-tools.md).
-- It can read every table, including tables added by later migrations, and can
-- change nothing.
--
-- PostgreSQL runs the files in /docker-entrypoint-initdb.d only when it creates
-- an empty database volume. For a database that already exists, run this file once
-- from the repository root (it is safe to run again):
--   docker compose -f infra/compose.dev.yml exec -T postgres psql -U selenly -d selenly < infra/postgres/init/10-readonly-role.sql
--
-- Development only: the password is public on purpose, like the others in compose.dev.yml.

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'readonly') THEN
        CREATE ROLE readonly LOGIN PASSWORD 'readonly';
    END IF;
END
$$;

-- Built-in role (PostgreSQL 14+): SELECT on all tables and views, in every schema.
GRANT pg_read_all_data TO readonly;
