import net.ltgt.gradle.errorprone.errorprone
import org.gradle.api.tasks.testing.logging.TestExceptionFormat
import org.gradle.api.tasks.testing.logging.TestLogEvent
import org.springframework.boot.gradle.tasks.bundling.BootBuildImage

plugins {
    java
    alias(libs.plugins.spring.boot)
    alias(libs.plugins.spring.dependency.management)
    alias(libs.plugins.spotless)
    alias(libs.plugins.errorprone)
}

group = "dev.moonhowl"
version = "0.0.1-SNAPSHOT"
description = "Selenly appointment booking backend"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

repositories {
    mavenCentral()
}

dependencyManagement {
    imports {
        mavenBom("org.springframework.modulith:spring-modulith-bom:${libs.versions.spring.modulith.get()}")
    }
}

dependencies {
    // No versions here: they come from the Spring Boot and Spring Modulith BOMs.
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-jdbc")
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.flywaydb:flyway-database-postgresql")
    implementation("org.springframework.modulith:spring-modulith-starter-core")
    // Null-safety annotations (@NullMarked, @Nullable), the same ones Spring uses.
    implementation("org.jspecify:jspecify")
    runtimeOnly("org.postgresql:postgresql")

    // Starts infra/compose.dev.yml on bootRun. developmentOnly: not in tests, not in the production image.
    developmentOnly("org.springframework.boot:spring-boot-docker-compose")

    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.springframework.modulith:spring-modulith-starter-test")
    testImplementation("org.testcontainers:testcontainers-postgresql")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")

    // Compiler plugins: they check the code while it compiles and are not part of the application.
    errorprone(libs.error.prone.core)
    errorprone(libs.nullaway)
}

// Formatting: `./gradlew spotlessApply` fixes it, `./gradlew check` fails when it is wrong.
spotless {
    java {
        palantirJavaFormat(libs.versions.palantir.java.format.get())
    }
}

// Error Prone finds common bugs at compile time; NullAway adds null safety on top of it.
tasks.withType<JavaCompile>().configureEach {
    options.errorprone {
        disableWarningsInGeneratedCode = true
        // Every type in our packages is non-null unless annotated @Nullable (JSpecify).
        // A possible NullPointerException is a compile error, not a crash in production.
        error("NullAway")
        option("NullAway:AnnotatedPackages", "dev.moonhowl.selenly")
        option("NullAway:JSpecifyMode", "true")
        option("NullAway:CustomContractAnnotations", "org.springframework.lang.Contract")
    }
}

tasks.named<JavaCompile>("compileTestJava") {
    // Tests set fields in @BeforeEach and use mocks: null checks there add noise, not safety.
    // The other Error Prone checks still run on test code.
    options.errorprone.disable("NullAway")
}

tasks.withType<Test> {
    useJUnitPlatform()
    testLogging {
        // Print why a test failed in the terminal and in CI logs, not only in the HTML report.
        events(TestLogEvent.FAILED, TestLogEvent.SKIPPED)
        exceptionFormat = TestExceptionFormat.FULL
    }
}

// The container image (./gradlew bootBuildImage, used by ./scripts/prod-local.sh and CI).
tasks.named<BootBuildImage>("bootBuildImage") {
    // A fixed builder version instead of the plugin's default ":latest", so every build uses
    // the same buildpacks and JRE until Renovate proposes a newer one (3 days after release).
    // ":latest" broke on 2026-10-23, when it pointed to an arm64-only image:
    // https://github.com/paketo-buildpacks/builder-noble-java-tiny/issues/344
    builder.set("docker.io/paketobuildpacks/builder-noble-java-tiny:0.0.200")
    // Build for x86 servers (amd64), whatever the machine runs.
    // For an ARM server (e.g. Oracle Ampere), change this to "linux/arm64".
    imagePlatform.set("linux/amd64")
}
