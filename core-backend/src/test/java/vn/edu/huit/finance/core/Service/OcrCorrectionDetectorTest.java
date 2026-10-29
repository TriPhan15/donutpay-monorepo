package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.Test;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Dto.ExtractedReceiptDto;
import vn.edu.huit.finance.core.Dto.OcrCorrectionDiff;
import vn.edu.huit.finance.core.Dto.OcrFieldCorrection;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class OcrCorrectionDetectorTest {

    private final OcrCorrectionDetector detector = new OcrCorrectionDetector();

    private static ExtractedReceiptDto ai(String seller, String total, LocalDateTime timestamp) {
        return ExtractedReceiptDto.builder().seller(seller)
                .totalCost(total == null ? null : new BigDecimal(total)).timestamp(timestamp).build();
    }

    @Test
    void sameValues_noCorrection() {
        ExtractedReceiptDto ai = ai("Highlands", "120000", LocalDateTime.of(2026, 5, 27, 10, 30));

        OcrCorrectionDiff result = detector.diff(ai, "Highlands", new BigDecimal("120000"), LocalDate.of(2026, 5, 27));

        assertTrue(result.corrections().isEmpty());
        // Every field the user sent equals the AI again: a correction stored earlier for it is stale.
        assertEquals(List.of(OcrField.SELLER_NAME, OcrField.TOTAL_COST, OcrField.RECEIPT_DATE), result.clearedFields());
    }

    @Test
    void totalDiffers_oneTotalCorrection() {
        OcrCorrectionDiff result = detector.diff(ai("Highlands", "120000", null), null, new BigDecimal("150000"), null);

        assertEquals(List.of(new OcrFieldCorrection(OcrField.TOTAL_COST, "120000", "150000")), result.corrections());
        assertTrue(result.clearedFields().isEmpty());
    }

    @Test
    void scaleOnly_120000_vs_120000_00_noCorrection() {
        OcrCorrectionDiff result = detector.diff(ai(null, "120000", null), null, new BigDecimal("120000.00"), null);

        assertTrue(result.corrections().isEmpty());
        assertEquals(List.of(OcrField.TOTAL_COST), result.clearedFields());
    }

    @Test
    void aiReadNothing_aiValueNull() {
        OcrCorrectionDiff result = detector.diff(ExtractedReceiptDto.empty(), "Cửa hàng A", new BigDecimal("50000.50"),
                LocalDate.of(2026, 1, 2));

        assertEquals(List.of(
                new OcrFieldCorrection(OcrField.SELLER_NAME, null, "Cửa hàng A"),
                new OcrFieldCorrection(OcrField.TOTAL_COST, null, "50000.5"),
                new OcrFieldCorrection(OcrField.RECEIPT_DATE, null, "2026-01-02")), result.corrections());
        assertTrue(result.clearedFields().isEmpty());
    }

    @Test
    void nullUserValues_ignored() {
        // Not sent is not compared: neither a correction nor a cleared field.
        assertTrue(detector.diff(ai("Highlands", "120000", null), null, null, null).isEmpty());
    }

    @Test
    void sellerTrimmedEqual_noCorrection() {
        OcrCorrectionDiff result = detector.diff(ai("Highlands", null, null), "  Highlands ", null, null);

        assertTrue(result.corrections().isEmpty());
        assertEquals(List.of(OcrField.SELLER_NAME), result.clearedFields());
    }

    @Test
    void sellerDiffersByCase_isACorrection() {
        assertEquals(1, detector.diff(ai("Highlands", null, null), "highlands", null, null).corrections().size());
    }
}
