package dev.moonhowl.selenly;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModules;

class ModularityTests {

    private final ApplicationModules modules = ApplicationModules.of(SelenlyApplication.class);

    @Test
    void verifiesModuleBoundaries() {
        modules.verify();
    }
}
