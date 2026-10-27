package vn.edu.huit.finance.core.Repository;

import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import vn.edu.huit.finance.core.Entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    List<User> findByWalletBalanceLessThan(BigDecimal amount);

    Optional<User> findByEmail(String email);
    Optional<User> findByUsername(String username);
    /**
     * Chuẩn RFM của mọi người dùng: chỉ khoản chi, từ {@code windowStart}, bỏ khoản góp tiết kiệm; ngày ở tương lai
     * tính là hôm nay (LEAST của PostgreSQL bỏ qua NULL nên dòng không có khoản chi
     * phải được loại bằng CASE). Người không có khoản chi nào nhận recency = {@code noActivityDays}, frequency 0, monetary 0.
     */
    @Query(value = "SELECT u.id AS \"userId\", " +
            "CAST(COALESCE(EXTRACT(DAY FROM (CAST(:now AS TIMESTAMP) - MAX(CASE WHEN t.id IS NULL THEN NULL ELSE LEAST(t.transaction_date, CAST(:now AS TIMESTAMP)) END))), " +
            "CAST(:noActivityDays AS NUMERIC)) AS INTEGER) AS \"recency\", " +
            "COUNT(t.id) AS \"frequency\", " +
            "COALESCE(SUM(t.amount), 0) AS \"monetary\" " +
            "FROM users u LEFT JOIN transactions t ON t.user_id = u.id AND t.is_expense = TRUE " +
            "AND t.transaction_date >= :windowStart " +
            "AND NOT EXISTS (SELECT 1 FROM categories c WHERE c.id = t.category_id AND c.name = :excludedCategoryName) " +
            "GROUP BY u.id", nativeQuery = true)
    List<UserRfmRow> calculateAllUsersRfm(@org.springframework.data.repository.query.Param("windowStart") LocalDateTime windowStart,
                                          @org.springframework.data.repository.query.Param("now") LocalDateTime now,
                                          @org.springframework.data.repository.query.Param("excludedCategoryName") String excludedCategoryName,
                                          @org.springframework.data.repository.query.Param("noActivityDays") int noActivityDays);

    /** Gán một nhãn cho nhiều người dùng bằng một UPDATE; chạy trong giao dịch của người gọi (CustomerSegmentationService). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE User u SET u.aiLabel = :label WHERE u.id IN :ids")
    int updateAiLabelForUsers(@org.springframework.data.repository.query.Param("label") String label,
                              @org.springframework.data.repository.query.Param("ids") Collection<Long> ids);

    @Query("SELECT u.aiLabel, COUNT(u) FROM User u WHERE u.aiLabel IS NOT NULL GROUP BY u.aiLabel")
    List<Object[]> countUsersByAiLabel();

    long countByAiLabel(String aiLabel);

    /**
     * Records the latest activity of a user: one UPDATE of last_action_time and of nothing else, so a copy of the user
     * read earlier can never write back its balance, profile, role, password or credentials version. Runs in its own
     * transaction (JwtAuthFilter has none). Returns the rows changed: 0 once the account is gone.
     */
    @Modifying
    @Transactional
    @Query("UPDATE User u SET u.lastActionTime = :lastActionTime WHERE u.id = :userId")
    int updateLastActionTime(@org.springframework.data.repository.query.Param("userId") Long userId,
                             @org.springframework.data.repository.query.Param("lastActionTime") LocalDateTime lastActionTime);

    /**
     * Stores a new password hash and ends every session of the user, in ONE atomic UPDATE: the hash and
     * credentials_version + 1 are written together or not at all. The only write either column gets on an existing row
     * (neither is updatable through the entity). Matches only while the row still has {@code expectedVersion}, so it can
     * never be applied on top of a change it did not see: 0 rows changed means nothing was written. Needs the caller's
     * transaction, which also holds the row lock. Pending changes are flushed first, the persistence context is left as it
     * is. Returns the rows changed.
     */
    @Modifying(flushAutomatically = true)
    @Query("UPDATE User u SET u.password = :passwordHash, u.credentialsVersion = u.credentialsVersion + 1 "
            + "WHERE u.id = :id AND u.credentialsVersion = :expectedVersion")
    int updatePasswordAndEndSessions(@org.springframework.data.repository.query.Param("id") Long id,
                                     @org.springframework.data.repository.query.Param("passwordHash") String passwordHash,
                                     @org.springframework.data.repository.query.Param("expectedVersion") Integer expectedVersion);
}
