package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** A15: the admin lists never load a whole table, whatever ?size= says. */
class AdminPageSizeTest {

    @ParameterizedTest
    @CsvSource({"10, 10", "1, 1", "100, 100", "101, 100", "1000000, 100", "0, 10", "-5, 10"})
    void thePageSizeIsKeptBetweenOneAndTheMaximum(int asked, int used) {
        assertEquals(used, AdminController.normalizePageSize(asked));
    }
}
