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
| `./gradlew spotlessApply` | formats all Java code (the Git hook does it for staged files) |
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

## Code quality

All of it runs in `./gradlew check`, so CI enforces it.

- **Formatting:** [Spotless](https://github.com/diffplug/spotless) with [palantir-java-format](https://github.com/palantir/palantir-java-format). Do not format by hand: `./gradlew spotlessApply`, the Git hook, or the palantir-java-format plugin in IntelliJ.
- **Bug patterns:** [Error Prone](https://errorprone.info) runs inside the compiler and turns common mistakes into compile errors.
- **Null safety:** [NullAway](https://github.com/uber/NullAway) in [JSpecify](https://jspecify.dev) mode. In every package under `dev.moonhowl.selenly`, a type is non-null unless it is annotated `@Nullable` (`org.jspecify.annotations.Nullable`):

  ```java
  // Compile error: the method may return null, but its type says it never does.
  String findName(UUID id) { return names.get(id); }

  // OK: the caller has to handle null.
  @Nullable String findName(UUID id) { return names.get(id); }
  ```

  Every new package gets a `package-info.java` with `@NullMarked` (see [the root one](src/main/java/dev/moonhowl/selenly/package-info.java)), so IntelliJ shows the same warnings as the build. NullAway is off for test code.

## Dependencies and versions

- Versions live in the version catalog: [`gradle/libs.versions.toml`](gradle/libs.versions.toml).
- Spring starters are declared without versions in [`build.gradle.kts`](build.gradle.kts): the Spring Boot and Spring Modulith BOMs choose matching versions.
- Do not add a dependency without discussing it first (in the issue or the pull request).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `spotlessJavaCheck` fails in `./gradlew check` | run `./gradlew spotlessApply` and commit the result |
| Spotless fails with `IllegalAccessError` mentioning `com.sun.tools.javac` | add to `backend/gradle.properties`: `org.gradle.jvmargs=-Xmx1g --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED`, then `./gradlew --stop` |
| NullAway reports a false positive | prefer making the code clearer; if it is really safe, explain it in a comment and use `@SuppressWarnings("NullAway")` on the smallest possible scope |
