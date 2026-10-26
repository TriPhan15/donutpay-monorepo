package vn.edu.huit.finance.core.Entity;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** The longest range each period type allows, both end days included. */
class BudgetPeriodTypeTest {

    private static final LocalDate NEW_YEAR_2026 = LocalDate.of(2026, 1, 1);
    private static final LocalDate NEW_YEAR_2028 = LocalDate.of(2028, 1, 1);

    @Test
    void aYearAllowsACommonYearAndALeapYearButNotOneDayMore() {
        assertTrue(BudgetPeriodType.YEAR.allowsRange(NEW_YEAR_2026, LocalDate.of(2026, 12, 31)), "365 days");
        assertTrue(BudgetPeriodType.YEAR.allowsRange(NEW_YEAR_2028, LocalDate.of(2028, 12, 31)), "366 days, 2028 is a leap year");
        assertFalse(BudgetPeriodType.YEAR.allowsRange(NEW_YEAR_2028, LocalDate.of(2029, 1, 1)), "367 days");
        assertFalse(BudgetPeriodType.YEAR.allowsRange(NEW_YEAR_2026, LocalDate.of(2027, 1, 2)), "367 days");
    }

    @Test
    void theShorterPeriodsKeepTheirLimits() {
        assertTrue(BudgetPeriodType.WEEK.allowsRange(NEW_YEAR_2026, LocalDate.of(2026, 1, 7)));
        assertFalse(BudgetPeriodType.WEEK.allowsRange(NEW_YEAR_2026, LocalDate.of(2026, 1, 8)));
        assertTrue(BudgetPeriodType.MONTH.allowsRange(NEW_YEAR_2026, LocalDate.of(2026, 1, 31)));
        assertFalse(BudgetPeriodType.MONTH.allowsRange(NEW_YEAR_2026, LocalDate.of(2026, 2, 1)));
    }

    @Test
    void everyNameFitsTheColumnAndTheMigrationKnowsEveryName() {
        // budgets.period_type is varchar(10), and budget-period-year-migration.sql allows exactly these three names.
        assertEquals(3, BudgetPeriodType.values().length, "a new period type needs the CHECK constraint widened by hand");
        for (BudgetPeriodType type : BudgetPeriodType.values()) {
            assertTrue(type.name().length() <= 10, type.name());
        }
    }
}
