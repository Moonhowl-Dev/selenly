# Backend

Spring Boot application, built as a modular monolith: one process and one deployment, with module boundaries enforced by [Spring Modulith](https://spring.io/projects/spring-modulith).

## Requirements

- Java 25, the version pinned in [`../.sdkmanrc`](../.sdkmanrc). If it is missing, Gradle downloads it for this build.
- Nothing else: the Gradle wrapper (`./gradlew`) downloads the right Gradle version by itself.

New to the project? Set up your environment first: [docs/onboarding/windows-wsl.md](../docs/onboarding/windows-wsl.md).

## Commands

Run them in this folder (`backend/`).

| Command | What it does |
|---|---|
| `./gradlew check` | builds the code and runs all checks and tests (the same as CI); needs a running Docker |
| `./gradlew test --tests 'dev.moonhowl.selenly.ModularityTests'` | runs a single test class |
| `./gradlew bootRun` | starts PostgreSQL, Keycloak and Mailpit in Docker, then the application on http://localhost:8080 |

The HTML test report is written to `build/reports/tests/test/index.html`. In WSL, open it with `explorer.exe build/reports/tests/test`.

`bootRun` needs a running Docker. It starts the services from [`../infra/compose.dev.yml`](../infra/compose.dev.yml), connects to that PostgreSQL by itself, applies the migrations, and stops the services when you stop the application with `Ctrl+C`. Addresses, logins and Docker commands: [infra/README.md](../infra/README.md).

At this stage the application has no endpoints, so http://localhost:8080 answers with a 404 page.

## Database

- PostgreSQL 18. The schema is created and changed only by [Flyway](https://documentation.red-gate.com/flyway) migrations in [`src/main/resources/db/migration`](src/main/resources/db/migration), applied on every start. Hibernate never generates tables.
- File names: `V<number>__<description>.sql`, with **two** underscores, e.g. `V2__event_publication.sql`. A wrong name fails the start instead of being skipped.
- Never edit a migration that is already on `main`: Flyway stores a checksum of every applied file and refuses to start when one changes. Add a new migration instead.
- Rules for business tables: `business_id uuid NOT NULL REFERENCES business (id)` and an index that starts with `business_id`; keys `uuid DEFAULT uuidv7()`; time as `timestamptz`.

Tests run against a throwaway PostgreSQL 18 started by [Testcontainers](https://java.testcontainers.org/), not against the database from `compose.dev.yml`. To use it in a test, add `@Import(TestcontainersConfiguration.class)`, as in [`SelenlyApplicationTests`](src/test/java/dev/moonhowl/selenly/SelenlyApplicationTests.java).

To look at the local database, run from the repository root: `docker compose -f infra/compose.dev.yml exec postgres psql -U selenly`, then `\dt` lists the tables and `\q` quits.

## Modules

Every package directly under `dev.moonhowl.selenly` is a module:

| Module | Responsible for |
|---|---|
| `identity` | users, profile, link to the Keycloak account, memberships |
| `business` | salon settings (the tenant in stage 2) |
| `catalog` | service categories and services |
| `staff` | staff members, assigned services, weekly schedules and exceptions |
| `availability` | the free-slot algorithm (no tables of its own) |
| `booking` | appointments and their lifecycle, salon clients |
| `notification` | emails and reminders |

None of them exist yet; each is added in the milestone that needs it.

### Boundary rules

- Classes in a module's main package (e.g. `dev.moonhowl.selenly.staff.StaffApi`) are its public API. Subpackages (e.g. `staff.internal`) are private to the module.
- Other modules use only the public API. Queries go through it synchronously; side effects go through events (`AppointmentBooked` → `notification`).
- Modules do not share JPA entities. A reference to another module's data is its ID (`UUID serviceId`), never a `@ManyToOne` relation.

[`ModularityTests`](src/test/java/dev/moonhowl/selenly/ModularityTests.java) calls `ApplicationModules.verify()` and fails the build when a module uses another module's private classes or when modules depend on each other in a cycle.

## Dependencies and versions

- Versions live in the version catalog: [`gradle/libs.versions.toml`](gradle/libs.versions.toml).
- Spring starters are declared without versions in [`build.gradle.kts`](build.gradle.kts): the Spring Boot and Spring Modulith BOMs choose matching versions.
- Do not add a dependency without discussing it first (in the issue or the pull request).
