package dev.moonhowl.selenly;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * A real PostgreSQL in Docker for tests. Add {@code @Import(TestcontainersConfiguration.class)}
 * to a test that needs the database.
 *
 * <p>{@code @ServiceConnection} passes the container's URL, user and password to Spring Boot,
 * so tests need no datasource properties. Spring starts the container once and reuses it for
 * every test that shares the same application context.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

    @Bean
    @ServiceConnection
    PostgreSQLContainer postgresContainer() {
        // Keep the image in sync with infra/compose.dev.yml.
        return new PostgreSQLContainer(DockerImageName.parse("postgres:18.6"));
    }
}
