# Backend

Spring Boot 4.1 on Java 25, Gradle with the Kotlin DSL. Root package: `dev.moonhowl.selenly`. Explanations for people: [README.md](README.md).

## Commands

Run them in `backend/`.

- `./gradlew check`: everything CI runs. Needs a running Docker (Testcontainers).
- `./gradlew test --tests 'dev.moonhowl.selenly.ModularityTests'`: one test class (use the fully qualified name).
- `./gradlew spotlessApply`: formats Java code with palantir-java-format. Never format by hand.
- `./gradlew bootRun`: the application on <http://localhost:8080> with the services from `../infra/compose.dev.yml`.

## Modules

- Every package directly under `dev.moonhowl.selenly` is a Spring Modulith module: `identity`, `business`, `catalog`, `staff`, `availability`, `booking`, `notification`. Create a module only when its milestone needs it.
- Classes in a module's root package are its public API. Subpackages (`internal`, `web`, …) are private to the module.
- Another module may only call the public API. Queries are synchronous calls; side effects go through events (for example `AppointmentBooked` handled in `notification`).
- No JPA relations between modules: refer to another module's data by its ID (`UUID serviceId`).
- `ModularityTests` (`ApplicationModules.verify()`) must stay green; never weaken it.

## Code

- Null safety: NullAway in JSpecify mode. Types are non-null unless annotated `@Nullable` (`org.jspecify.annotations.Nullable`). Every new package gets a `package-info.java` with `@NullMarked`.
- Error Prone and NullAway errors point at real problems: change the code. Suppress only when it is provably safe, on the smallest scope, with a comment explaining why.
- Time: `Instant` for moments, read from an injected `java.time.Clock`. Never call `Instant.now()`, `LocalDateTime.now()` or `LocalDate.now()` without a `Clock`. Weekly schedules are `LocalTime` in the salon's time zone (`business.time_zone`, `Europe/Warsaw` by default); appointments are stored as `timestamptz`.
- Web layer (from M1): controllers live in the module's `web` subpackage and return DTOs, never entities. Every endpoint under `/admin` and `/staff` has `@PreAuthorize`. Request bodies are validated with Jakarta Bean Validation. Errors are Problem Details (RFC 9457).
- Dependencies: versions only in `gradle/libs.versions.toml`; Spring starters are declared without versions (the Spring Boot and Spring Modulith BOMs choose them).

## Database

- PostgreSQL 18. The schema changes only through Flyway migrations in `src/main/resources/db/migration`; Hibernate never creates tables.
- File name `V<next number>__<snake_case_description>.sql` with two underscores. Never edit a migration that is already on `main`.
- Business tables have `business_id uuid NOT NULL REFERENCES business (id)` and an index that starts with `business_id`. Primary keys are `uuid DEFAULT uuidv7()`, time columns `timestamptz`.
- Double bookings are prevented by the exclusion constraint on `appointment`; keep it as the source of truth and translate its violation into a conflict response instead of replacing it with checks in Java.
- Changes that lock or rewrite a large table are described in the pull request.

## Tests

- Integration tests run against a real PostgreSQL from Testcontainers: `@Import(TestcontainersConfiguration.class)`. Never use H2 or another database.
- A module on its own: `@ApplicationModuleTest`. Controllers: `MockMvcTester`.
- Assertions with AssertJ. Time-dependent code is tested with `Clock.fixed(...)`, including the daylight saving time changes in `Europe/Warsaw`. No `Thread.sleep`.
