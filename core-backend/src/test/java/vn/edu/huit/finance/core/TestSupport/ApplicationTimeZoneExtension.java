package vn.edu.huit.finance.core.TestSupport;

import org.junit.jupiter.api.extension.Extension;

import java.util.TimeZone;

/**
 * Sets the zone CoreBackendApplication.init() sets, before the first test of the JVM. That method only runs once a Spring
 * context has started, and by then H2 has already cached the zone of the machine: on a machine in UTC (the CI runner) every
 * LocalDate then came back from H2 one day early. Registered through META-INF/services and junit-platform.properties.
 */
public class ApplicationTimeZoneExtension implements Extension {

    static {
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
    }
}
