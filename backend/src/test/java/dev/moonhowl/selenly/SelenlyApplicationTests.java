package dev.moonhowl.selenly;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class SelenlyApplicationTests {

    /**
     * Starts the whole application against PostgreSQL 18 in Testcontainers.
     * Flyway applies every migration on startup, so a broken migration fails this test.
     */
    @Test
    void contextLoads() {}
}
