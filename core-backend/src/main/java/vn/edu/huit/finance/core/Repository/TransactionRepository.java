package vn.edu.huit.finance.core.Repository;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Util.SavingsContributions;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    /** One transaction with its owner, category and receipt in a single query, so mapping it to a DTO adds no queries. */
    @Query("SELECT t FROM Transaction t " +
           "JOIN FETCH t.user " +
           "JOIN FETCH t.category " +
           "LEFT JOIN FETCH t.receipt " +
           "WHERE t.id = :id")
    Optional<Transaction> findDetailedById(@Param("id") Long id);

    /**
     * One transaction with its receipt, which is all the search document of it needs besides the row itself (the owner's
     * id comes from the foreign key, without loading the user).
     */
    @Query("SELECT t FROM Transaction t LEFT JOIN FETCH t.receipt WHERE t.id = :id")
    Optional<Transaction> findForSearchIndex(@Param("id") Long id);

    /**
     * The next page of every user's transactions with their receipts, ordered by id, for a rebuild of the search index:
     * the rows after {@code lastId} (keyset paging, so a row deleted meanwhile cannot make a later page skip one).
     */
    @Query("SELECT t FROM Transaction t LEFT JOIN FETCH t.receipt WHERE t.id > :lastId ORDER BY t.id")
    java.util.List<Transaction> findNextForSearchIndex(@Param("lastId") Long lastId, org.springframework.data.domain.Pageable pageable);

    /**
     * The transaction this user already created with this client id (the idempotency key of a checkout), if any. Only what
     * the transaction row itself holds is needed to answer a repeated checkout, so nothing is fetched along with it.
     */
    @Query("SELECT t FROM Transaction t WHERE t.user.id = :userId AND t.clientId = :clientId")
    Optional<Transaction> findByUserIdAndClientId(@Param("userId") Long userId, @Param("clientId") String clientId);

    /**
     * The user's transactions a scanned receipt could be a second copy of: same direction, same amount, a date from
     * minuteStart (inclusive) to minuteEnd (exclusive), oldest first. The receipt comes along in the same query, since
     * the caller compares its seller (one statement, however many rows match).
     */
    @Query("SELECT t FROM Transaction t LEFT JOIN FETCH t.receipt " +
           "WHERE t.user.id = :userId AND t.isExpense = :isExpense AND t.amount = :amount " +
           "AND t.transactionDate >= :minuteStart AND t.transactionDate < :minuteEnd " +
           "ORDER BY t.id")
    List<Transaction> findPossibleReceiptDuplicates(@Param("userId") Long userId,
                                                    @Param("isExpense") boolean isExpense,
                                                    @Param("amount") BigDecimal amount,
                                                    @Param("minuteStart") java.time.LocalDateTime minuteStart,
                                                    @Param("minuteEnd") java.time.LocalDateTime minuteEnd);

    @Query("SELECT t FROM Transaction t " +
           "JOIN FETCH t.user " +
           "JOIN FETCH t.category " +
           "LEFT JOIN FETCH t.receipt r " +
           "WHERE t.user.id = :userId " +
           "AND (:categoryId IS NULL OR t.category.id = :categoryId) " +
           "AND (:minPrice IS NULL OR t.amount >= :minPrice) " +
           "AND (:maxPrice IS NULL OR t.amount <= :maxPrice) " +
           "AND (CAST(:vendorName AS String) IS NULL OR LOWER(r.vendorName) LIKE LOWER(CONCAT('%', CAST(:vendorName AS String), '%')))")
    List<Transaction> filterTransactions(
            @Param("userId") Long userId,
            @Param("categoryId") Long categoryId,
            @Param("minPrice") BigDecimal minPrice,
            @Param("maxPrice") BigDecimal maxPrice,
            @Param("vendorName") String vendorName,
            Sort sort
    );

    @Query("SELECT SUM(t.amount) FROM Transaction t")
    BigDecimal sumTotalVolume();

    @Query("SELECT t.receipt.vendorName, COUNT(t.id) as freq " +
            "FROM Transaction t " +
            "WHERE t.user.id = :userId AND t.receipt.vendorName IS NOT NULL " +
            "GROUP BY t.receipt.vendorName " +
            "ORDER BY freq DESC")
    List<Object[]> findPopularVendors(@org.springframework.data.repository.query.Param("userId") Long userId);


    Transaction findTopByUserIdOrderByAmountDesc(Long userId);

    /** Every transaction of a category, with its owner, for CategoryService.renameCategory. */
    @Query("SELECT t FROM Transaction t JOIN FETCH t.user WHERE t.category.id = :categoryId")
    List<Transaction> findAllByCategory_Id(@Param("categoryId") Long categoryId);


    @Query("SELECT t FROM Transaction t JOIN FETCH t.category LEFT JOIN FETCH t.receipt WHERE t.user.id = :userId AND t.voucherCode IS NOT NULL")
    List<Transaction> findByUserIdAndVoucherCodeNotNull(@Param("userId") Long userId);

    long countByTransactionDateBetween(java.time.LocalDateTime startDate, java.time.LocalDateTime endDate);


    @Query(value = "SELECT t FROM Transaction t JOIN FETCH t.category LEFT JOIN FETCH t.receipt WHERE t.user.id = :userId",
           countQuery = "SELECT count(t) FROM Transaction t WHERE t.user.id = :userId")
    List<Transaction> findByUserId(@Param("userId") Long userId, org.springframework.data.domain.Pageable pageable);


    @Query("SELECT t FROM Transaction t JOIN FETCH t.category LEFT JOIN FETCH t.receipt WHERE t.user.id = :userId ORDER BY t.transactionDate DESC")
    List<Transaction> findByUserIdOrderByTransactionDateDesc(@Param("userId") Long userId);

    /**
     * Every user's spending from rangeStart, inclusive, to rangeEnd, exclusive: rows [userId, username, total], highest
     * first. Savings contributions are left out (D1), like {@link #sumSpendingBetween}.
     */
    @Query("SELECT t.user.id, t.user.username, SUM(t.amount) as totalSpent FROM Transaction t WHERE t.isExpense = true " +
           "AND t.category.name <> :excludedCategoryName " +
           "AND t.transactionDate >= :rangeStart AND t.transactionDate < :rangeEnd " +
           "GROUP BY t.user.id, t.user.username ORDER BY totalSpent DESC")
    List<Object[]> sumExpensesByUserBetween(@Param("rangeStart") java.time.LocalDateTime rangeStart,
                                            @Param("rangeEnd") java.time.LocalDateTime rangeEnd,
                                            @Param("excludedCategoryName") String excludedCategoryName);

    default List<Object[]> sumExpensesByUserBetween(java.time.LocalDateTime rangeStart, java.time.LocalDateTime rangeEnd) {
        return sumExpensesByUserBetween(rangeStart, rangeEnd, SavingsContributions.CATEGORY_NAME);
    }

    /**
     * What a user spent (expenses only, savings contributions left out) from rangeStart, inclusive, to rangeEnd,
     * exclusive; null when there is nothing.
     */
    @Query("SELECT SUM(t.amount) FROM Transaction t WHERE t.user.id = :userId AND t.isExpense = true " +
           "AND t.category.name <> :excludedCategoryName " +
           "AND t.transactionDate >= :rangeStart AND t.transactionDate < :rangeEnd")
    BigDecimal sumSpendingBetween(@Param("userId") Long userId,
                                  @Param("rangeStart") java.time.LocalDateTime rangeStart,
                                  @Param("rangeEnd") java.time.LocalDateTime rangeEnd,
                                  @Param("excludedCategoryName") String excludedCategoryName);

    default BigDecimal sumSpendingBetween(Long userId, java.time.LocalDateTime rangeStart, java.time.LocalDateTime rangeEnd) {
        return sumSpendingBetween(userId, rangeStart, rangeEnd, SavingsContributions.CATEGORY_NAME);
    }

    /** Same as {@link #sumSpendingBetween}, restricted to one category. */
    @Query("SELECT SUM(t.amount) FROM Transaction t WHERE t.user.id = :userId AND t.isExpense = true " +
           "AND t.category.id = :categoryId AND t.transactionDate >= :rangeStart AND t.transactionDate < :rangeEnd")
    BigDecimal sumExpensesInCategoryBetween(@Param("userId") Long userId,
                                            @Param("categoryId") Long categoryId,
                                            @Param("rangeStart") java.time.LocalDateTime rangeStart,
                                            @Param("rangeEnd") java.time.LocalDateTime rangeEnd);

    /**
     * The LIKE pattern that finds {@code q} anywhere in a text, case ignored: lowercased, with the characters LIKE treats
     * as wildcards ({@code \ % _}) escaped by a backslash (the ESCAPE of {@link #searchIdsByText}) so the user's text is
     * always literal, and wrapped in %.
     */
    static String likePattern(String q) {
        String escaped = q.toLowerCase(java.util.Locale.ROOT)
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
        return "%" + escaped + "%";
    }

    /**
     * The ids of the user's transactions whose note, category, location, payment method or receipt seller contain the text
     * of {@code pattern} (built by {@link #likePattern}), newest first. Only ids: the rows are loaded by
     * {@link #findAllByIdInAndUserIdWithReceipt}, the same way as for hits of the search index.
     */
    @Query(value = "SELECT t.id FROM Transaction t LEFT JOIN t.receipt r " +
                   "WHERE t.user.id = :userId AND (" +
                   "LOWER(t.note) LIKE :pattern ESCAPE '\\' OR LOWER(t.categoryName) LIKE :pattern ESCAPE '\\' " +
                   "OR LOWER(t.location) LIKE :pattern ESCAPE '\\' OR LOWER(t.paymentMethod) LIKE :pattern ESCAPE '\\' " +
                   "OR LOWER(r.vendorName) LIKE :pattern ESCAPE '\\') " +
                   "ORDER BY t.transactionDate DESC, t.id DESC",
           countQuery = "SELECT count(t) FROM Transaction t LEFT JOIN t.receipt r " +
                   "WHERE t.user.id = :userId AND (" +
                   "LOWER(t.note) LIKE :pattern ESCAPE '\\' OR LOWER(t.categoryName) LIKE :pattern ESCAPE '\\' " +
                   "OR LOWER(t.location) LIKE :pattern ESCAPE '\\' OR LOWER(t.paymentMethod) LIKE :pattern ESCAPE '\\' " +
                   "OR LOWER(r.vendorName) LIKE :pattern ESCAPE '\\')")
    org.springframework.data.domain.Page<Long> searchIdsByText(@Param("userId") Long userId,
                                                               @Param("pattern") String pattern,
                                                               org.springframework.data.domain.Pageable pageable);

    /**
     * The user's own transactions among {@code ids}, each with its category and receipt, in one statement. An id of another
     * user (a stale or foreign entry of the search index) matches nothing. The order is not that of {@code ids}.
     */
    @Query("SELECT t FROM Transaction t JOIN FETCH t.category LEFT JOIN FETCH t.receipt " +
           "WHERE t.id IN :ids AND t.user.id = :userId")
    List<Transaction> findAllByIdInAndUserIdWithReceipt(@Param("ids") java.util.Collection<Long> ids,
                                                        @Param("userId") Long userId);
}