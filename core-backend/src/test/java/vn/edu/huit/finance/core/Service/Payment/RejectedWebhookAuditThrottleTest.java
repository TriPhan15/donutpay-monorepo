package vn.edu.huit.finance.core.Service.Payment;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** A14: rejected webhooks cannot make action_logs grow without bound. */
class RejectedWebhookAuditThrottleTest {

    /** A clock the test moves by hand. */
    private static final class MovableClock extends Clock {
        private Instant now = Instant.parse("2026-10-29T00:00:00Z");

        void advance(java.time.Duration by) {
            now = now.plus(by);
        }

        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
    }

    private final MovableClock clock = new MovableClock();
    private final RejectedWebhookAuditThrottle throttle = new RejectedWebhookAuditThrottle(clock);

    @Test
    void theSameOrderCodeIsRecordedOncePerWindow_andAgainAfterIt() {
        assertTrue(throttle.shouldRecord("PAY1"));
        assertFalse(throttle.shouldRecord("PAY1"));
        assertFalse(throttle.shouldRecord("PAY1"));

        clock.advance(RejectedWebhookAuditThrottle.WINDOW);

        assertTrue(throttle.shouldRecord("PAY1"));
    }

    @Test
    void changingTheOrderCodeEveryTimeStillStopsAtTheCeiling() {
        int recorded = 0;
        for (int i = 0; i < RejectedWebhookAuditThrottle.MAX_ROWS_PER_WINDOW * 3; i++) {
            if (throttle.shouldRecord("PAY" + i)) {
                recorded++;
            }
        }
        assertEquals(RejectedWebhookAuditThrottle.MAX_ROWS_PER_WINDOW, recorded);

        clock.advance(RejectedWebhookAuditThrottle.WINDOW);
        assertTrue(throttle.shouldRecord("PAY-next-window"));
    }

    @Test
    void aMissingOrderCodeIsThrottledLikeAnyOther() {
        assertTrue(throttle.shouldRecord(null));
        assertFalse(throttle.shouldRecord(null));
    }
}
