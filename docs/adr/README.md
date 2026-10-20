# Architecture decision records

Short records of important architecture decisions: the context, the decision and its consequences. One page each.

## Adding a record

1. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md`, using the next free number (e.g. `0001-modular-monolith.md`).
2. Fill it in and open a pull request. When it is merged, set the status to **Accepted**.
3. Do not rewrite the decision in an accepted record. If the decision changes, write a new record and mark the old one as **Superseded by ADR-NNNN**.

## Index

| ADR | Decision | Status |
|---|---|---|
| | No records yet | |

## Planned

Decisions from the architecture plan that deserve a record:

1. Modular monolith instead of microservices
2. Double bookings are blocked by a PostgreSQL constraint, not an application lock or Redis
3. Backend-for-frontend with a session instead of tokens in the browser
4. Identity in Keycloak, roles in the application database
5. `business_id` from the first migration
6. Schedules in local time, appointments in `timestamptz`
7. UUIDv7 primary keys
8. API client generated from OpenAPI
9. Docker Desktop or Docker Engine for local development (both supported)
