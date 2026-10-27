package vn.edu.huit.finance.core.Dto;

import java.time.YearMonth;
import java.util.Objects;
import java.util.Set;

/**
 * Published inside the database transaction of every write to a transaction (create, edit, delete, receipt approval) and
 * handled once it has committed (TransactionalEventListener AFTER_COMMIT), by the Redis leaderboard and the search index.
 *
 * @param transactionId the transaction written (null only when the write did not yield an id)
 * @param userId        its owner
 * @param kind          UPSERTED when the row exists after the write, DELETED when it is gone
 * @param expenseMonths every month whose expense total this write may have changed (the month of the transaction before
 *                      and after, wherever it was an expense); empty when only text that can be searched changed
 */
public record TransactionChangedEvent(Long transactionId, Long userId, Kind kind, Set<YearMonth> expenseMonths) {

    public enum Kind { UPSERTED, DELETED }

    public TransactionChangedEvent {
        Objects.requireNonNull(kind, "kind");
        expenseMonths = expenseMonths == null ? Set.of() : Set.copyOf(expenseMonths);
    }

    /** The transaction exists after the write (created, edited, reconciled with its receipt). */
    public static TransactionChangedEvent upserted(Long transactionId, Long userId, Set<YearMonth> expenseMonths) {
        return new TransactionChangedEvent(transactionId, userId, Kind.UPSERTED, expenseMonths);
    }

    /** The transaction was deleted. */
    public static TransactionChangedEvent deleted(Long transactionId, Long userId, Set<YearMonth> expenseMonths) {
        return new TransactionChangedEvent(transactionId, userId, Kind.DELETED, expenseMonths);
    }
}
