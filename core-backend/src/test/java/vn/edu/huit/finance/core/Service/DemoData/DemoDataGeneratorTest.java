package vn.edu.huit.finance.core.Service.DemoData;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import vn.edu.huit.finance.core.Entity.DefaultCategory;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The generator alone, at a fixed moment: same data on every run, prices a person in Ho Chi Minh City would pay, a wallet
 * that never goes negative, and personas whose activity lands each of them in the RFM segment ai-service will give.
 */
class DemoDataGeneratorTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 21, 20, 0);
    private static final LocalDate TODAY = NOW.toLocalDate();
    private static final BigDecimal THOUSAND = BigDecimal.valueOf(1_000);
    // ai-service /admin/segment: CHURN above 120 days, AT-RISK above 30, VIP above 10 million.
    private static final long CHURN_RECENCY_DAYS = 120;
    private static final long AT_RISK_RECENCY_DAYS = 30;
    private static final BigDecimal VIP_MONETARY = BigDecimal.valueOf(10_000_000);
    // The categories DemoDataWriter picks receipts from.
    private static final Set<DefaultCategory> SCANNABLE =
            EnumSet.of(DefaultCategory.FOOD, DefaultCategory.GROCERIES, DefaultCategory.SHOPPING);

    private static List<DemoAccount> accounts;

    @BeforeAll
    static void generate() {
        accounts = new DemoDataGenerator(DemoDataGenerator.SEED).generate(NOW);
    }

    @Test
    void theSameSeedAtTheSameMomentGivesTheSameData() {
        assertThat(new DemoDataGenerator(DemoDataGenerator.SEED).generate(NOW)).isEqualTo(accounts);
    }

    @Test
    void twoDemoAccountsComeFirst_thenTheBackgroundAccounts() {
        assertThat(accounts).hasSize(2 + DemoDataGenerator.SALARIED_COUNT + DemoDataGenerator.NEWCOMER_COUNT
                + DemoDataGenerator.FADING_COUNT + DemoDataGenerator.CHURNED_COUNT);
        assertThat(accounts.get(0).username()).isEqualTo(DemoDataGenerator.OFFICE_WORKER_USERNAME);
        assertThat(accounts.get(0).persona()).isEqualTo(DemoPersona.OFFICE_WORKER);
        assertThat(accounts.get(1).username()).isEqualTo(DemoDataGenerator.STUDENT_USERNAME);
        assertThat(accounts.get(1).persona()).isEqualTo(DemoPersona.STUDENT);
        assertThat(accounts.stream().skip(2)).noneMatch(account -> account.persona().isDemoLogin());
    }

    @Test
    void usernamesEmailsAndPhonesAreUnique_andTheEmailsGoNowhere() {
        assertUnique(DemoAccount::username);
        assertUnique(DemoAccount::email);
        assertUnique(DemoAccount::phone);
        assertThat(accounts).allSatisfy(account -> {
            assertThat(account.email()).isEqualTo(account.username() + DemoDataGenerator.EMAIL_DOMAIN);
            assertThat(account.username()).matches("[a-z0-9.]+");
            assertThat(account.phone()).matches("09\\d{8}");
        });
    }

    @Test
    void thereAreAFewThousandTransactions() {
        int total = accounts.stream().mapToInt(account -> account.transactions().size()).sum();
        assertThat(total).isBetween(2_000, 10_000);
    }

    @Test
    void everyAmountIsPositiveAndInWholeThousands_andNothingIsInTheFuture() {
        assertThat(allTransactions()).allSatisfy(transaction -> {
            assertThat(transaction.amount()).isPositive();
            assertThat(transaction.amount().remainder(THOUSAND)).isZero();
            assertThat(transaction.at()).isBeforeOrEqualTo(NOW);
            assertThat(transaction.note()).isNotBlank();
        });
    }

    @Test
    void theWalletNeverGoesNegative_andEndsAtIncomeMinusExpenses() {
        assertThat(accounts).allSatisfy(account -> {
            BigDecimal balance = BigDecimal.ZERO;
            for (DemoTransaction transaction : account.transactions()) {
                balance = balance.add(transaction.signedAmount());
                assertThat(balance).as("balance of %s at %s", account.username(), transaction.at()).isNotNegative();
            }
            assertThat(account.walletBalance()).isEqualByComparingTo(balance);
        });
    }

    @Test
    void transactionsAreListedOldestFirst_startingWithTheOpeningBalance() {
        assertThat(accounts).allSatisfy(account -> {
            assertThat(account.transactions()).isSortedAccordingTo(Comparator.comparing(DemoTransaction::at));
            DemoTransaction first = account.transactions().get(0);
            assertThat(first.category()).isEqualTo(DefaultCategory.OTHER_INCOME);
            assertThat(first.at().toLocalTime()).isEqualTo(LocalTime.MIDNIGHT);
        });
    }

    @Test
    void currentUsersHaveTheThreePreviousMonthsAndThisOne() {
        LocalDate historyStart = LocalDate.of(2026, 7, 1);
        assertThat(accounts).filteredOn(account -> isCurrentUser(account.persona())).allSatisfy(account -> {
            assertThat(account.transactions().get(0).at().toLocalDate()).isEqualTo(historyStart);
            assertThat(daysSinceLast(account)).isLessThanOrEqualTo(AT_RISK_RECENCY_DAYS);
            assertThat(volume(account)).isGreaterThan(VIP_MONETARY);
        });
    }

    @Test
    void theOfficeWorkerIsPaidEarlyInEveryMonth_andPaysRentOnTheFifth() {
        DemoAccount office = accounts.get(0);
        for (LocalDate month = LocalDate.of(2026, 7, 1); month.isBefore(TODAY); month = month.plusMonths(1)) {
            LocalDate first = month;
            assertThat(office.transactions()).as("salary of %s", month).anyMatch(t -> t.category() == DefaultCategory.SALARY
                    && t.at().toLocalDate().withDayOfMonth(1).equals(first) && t.at().getDayOfMonth() <= 5);
            assertThat(office.transactions()).as("rent of %s", month).anyMatch(t -> t.category() == DefaultCategory.HOUSING
                    && t.at().toLocalDate().equals(first.withDayOfMonth(5)));
        }
    }

    @Test
    void peopleSpendMoreOnEntertainmentAtTheWeekend() {
        long weekend = allTransactions().stream().filter(t -> t.category() == DefaultCategory.ENTERTAINMENT)
                .filter(t -> isWeekend(t.at().toLocalDate())).count();
        long weekdays = allTransactions().stream().filter(t -> t.category() == DefaultCategory.ENTERTAINMENT)
                .filter(t -> !isWeekend(t.at().toLocalDate())).count();
        // Two weekend days against five weekdays, yet more entertainment (the monthly Netflix bill is the weekday share).
        assertThat(weekend).isGreaterThan(weekdays);
    }

    @Test
    void newcomersStartedWithinAMonth_andStayUnderTheVipVolume() {
        assertThat(accountsOf(DemoPersona.NEWCOMER)).hasSize(DemoDataGenerator.NEWCOMER_COUNT).allSatisfy(account -> {
            long sinceFirst = ChronoUnit.DAYS.between(account.transactions().get(0).at().toLocalDate(), TODAY);
            assertThat(sinceFirst).isBetween((long) DemoDataGenerator.NEWCOMER_MIN_DAYS,
                    (long) DemoDataGenerator.NEWCOMER_MAX_DAYS);
            assertThat(volume(account)).isLessThan(VIP_MONETARY);
        });
    }

    @Test
    void fadingUsersStoppedBetweenOneAndFourMonthsAgo() {
        assertThat(accountsOf(DemoPersona.FADING)).hasSize(DemoDataGenerator.FADING_COUNT).allSatisfy(account ->
                assertThat(daysSinceLast(account)).isGreaterThan(AT_RISK_RECENCY_DAYS)
                        .isLessThanOrEqualTo(CHURN_RECENCY_DAYS));
    }

    @Test
    void churnedUsersStoppedMoreThanFourMonthsAgo() {
        assertThat(accountsOf(DemoPersona.CHURNED)).hasSize(DemoDataGenerator.CHURNED_COUNT).allSatisfy(account ->
                assertThat(daysSinceLast(account)).isGreaterThan(CHURN_RECENCY_DAYS));
    }

    @Test
    void theDemoAccountsHaveEnoughRecentShopsToScanTheirReceipts() {
        for (DemoAccount account : accounts.subList(0, 2)) {
            long shops = account.transactions().stream()
                    .filter(t -> SCANNABLE.contains(t.category()) && t.at().isAfter(NOW.minusDays(7)))
                    .map(DemoTransaction::note).distinct().count();
            assertThat(shops).isGreaterThanOrEqualTo(ReceiptScenario.forPersona(account.persona()).size());
        }
    }

    @Test
    void withoutDiacriticsDropsTheMarksTheWayTheModelOftenMisreadsThem() {
        assertThat(DemoDataGenerator.withoutDiacritics("Phúc Long Đặng")).isEqualTo("Phuc Long Dang");
    }

    // ------------------------------------------------------------------------------------------------------- helpers

    private static void assertUnique(Function<DemoAccount, String> key) {
        Set<String> seen = new HashSet<>();
        assertThat(accounts).allSatisfy(account -> assertThat(seen.add(key.apply(account))).isTrue());
    }

    private static List<DemoTransaction> allTransactions() {
        return accounts.stream().flatMap(account -> account.transactions().stream()).toList();
    }

    private static List<DemoAccount> accountsOf(DemoPersona persona) {
        return accounts.stream().filter(account -> account.persona() == persona).toList();
    }

    private static boolean isCurrentUser(DemoPersona persona) {
        return persona == DemoPersona.OFFICE_WORKER || persona == DemoPersona.STUDENT || persona == DemoPersona.SALARIED;
    }

    /** As ai-service receives it: whole days between the last transaction and now. */
    private static long daysSinceLast(DemoAccount account) {
        LocalDateTime last = account.transactions().get(account.transactions().size() - 1).at();
        return ChronoUnit.DAYS.between(last, NOW);
    }

    /** The RFM monetary value core-backend sends: the sum of every amount, income and expense alike. */
    private static BigDecimal volume(DemoAccount account) {
        return account.transactions().stream().map(DemoTransaction::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static boolean isWeekend(LocalDate day) {
        return day.getDayOfWeek() == DayOfWeek.SATURDAY || day.getDayOfWeek() == DayOfWeek.SUNDAY;
    }
}
