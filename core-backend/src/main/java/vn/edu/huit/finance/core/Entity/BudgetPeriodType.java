package vn.edu.huit.finance.core.Entity;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/**
 * How long a budget lasts: its date range may not be longer than {@code maxDays}. Stored by name in budgets.period_type
 * (and budgets_aud): a new constant needs the CHECK constraint of both tables widened by hand, see
 * src/main/resources/db/budget-period-year-migration.sql (ddl-auto=update never changes an existing CHECK).
 */
public enum BudgetPeriodType {
    WEEK(7),
    MONTH(31),
    /** A calendar year, 366 days at most so that a leap year fits. */
    YEAR(366);

    private final int maxDays;

    BudgetPeriodType(int maxDays) {
        this.maxDays = maxDays;
    }

    /** True when startDate..endDate, both days included, is no longer than this period type. */
    public boolean allowsRange(LocalDate startDate, LocalDate endDate) {
        return ChronoUnit.DAYS.between(startDate, endDate) + 1 <= maxDays;
    }
}
