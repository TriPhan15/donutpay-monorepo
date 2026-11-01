package vn.edu.huit.finance.core.Entity;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** The names of the receipt slices of the admin dashboard: three labels for the statuses it counts under their legacy names. */
class ReceiptStatusDashboardLabelTest {

    @ParameterizedTest
    @CsvSource({
            "SUCCESS, Thành công",
            "FAILED, Lỗi AI",
            "PENDING, Đang xử lý",
            "PROCESSING, Đang xử lý",
            "WAITING_FOR_REVIEW, Đang xử lý",
            "CANCELED, Đang xử lý",
            "something else, Đang xử lý",
            // The comparison is exact, as the dashboard has always made it: it gets the legacy names, in capitals.
            "success, Đang xử lý",
            "COMPLETED_RAW, Đang xử lý"
    })
    void aStatusNameIsShownUnderOneOfThreeLabels(String legacyName, String label) {
        assertEquals(label, ReceiptStatus.dashboardLabelOf(legacyName));
    }

    @Test
    void noStatusAtAllIsStillBeingProcessed() {
        assertEquals("Đang xử lý", ReceiptStatus.dashboardLabelOf(null));
    }

    @Test
    void theLabelsOfTheLegacyNamesOfEveryStatusAreTheOnesTheDashboardShows() {
        assertEquals("Thành công", ReceiptStatus.dashboardLabelOf(ReceiptStatus.COMPLETED_RAW.legacyName()));
        assertEquals("Thành công", ReceiptStatus.dashboardLabelOf(ReceiptStatus.EDITED.legacyName()));
        assertEquals("Thành công", ReceiptStatus.dashboardLabelOf(ReceiptStatus.APPROVED.legacyName()));
        assertEquals("Lỗi AI", ReceiptStatus.dashboardLabelOf(ReceiptStatus.FAILED.legacyName()));
        assertEquals("Đang xử lý", ReceiptStatus.dashboardLabelOf(ReceiptStatus.WAITING_FOR_REVIEW.legacyName()));
    }
}
