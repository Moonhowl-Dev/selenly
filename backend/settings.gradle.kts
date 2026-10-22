plugins {
    // Lets Gradle download the JDK required by the toolchain (Java 25) when it is not installed.
    // The version catalog is not available in this file, so the version is written here.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "selenly"
