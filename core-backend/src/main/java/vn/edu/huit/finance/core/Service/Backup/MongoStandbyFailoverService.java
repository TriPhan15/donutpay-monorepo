package vn.edu.huit.finance.core.Service.Backup;

import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.dao.TransientDataAccessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.CannotCreateTransactionException;
import org.springframework.transaction.TransactionSystemException;

import java.net.ConnectException;
import java.net.SocketException;
import java.sql.SQLException;
import java.sql.SQLTransientException;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Supplier;

/**
 * Bộ điều phối Chế độ Đọc Dự phòng (Read-Fallback) sang MongoDB khi PostgreSQL gặp sự cố
 * hoặc khi Quản trị viên bật công tắc diễn tập ({@code Force MongoDB Failover Mode}) trên {@code /admin/backup}.
 */
@Slf4j
@Service
public class MongoStandbyFailoverService {

    /** Thời gian giữ mạch ngắt tự động (30 giây) sau khi phát hiện PostgreSQL mất kết nối. */
    public static final long AUTO_FAILOVER_COOLDOWN_MS = 30_000L;

    public static final String SOURCE_POSTGRES = "POSTGRESQL";
    public static final String SOURCE_MONGO_STANDBY = "MONGODB_STANDBY";

    private final AtomicBoolean forceFailoverEnabled = new AtomicBoolean(false);
    private final AtomicLong autoFailoverUntilEpochMs = new AtomicLong(0L);
    private final AtomicBoolean standbyWritePending = new AtomicBoolean(false);

    public boolean isStandbyWritePending() {
        return standbyWritePending.get();
    }

    public void markStandbyWritePending(boolean pending) {
        standbyWritePending.set(pending);
    }

    public boolean isForceFailoverEnabled() {
        return forceFailoverEnabled.get();
    }

    public void setForceFailoverEnabled(boolean enabled) {
        boolean previous = forceFailoverEnabled.getAndSet(enabled);
        if (!enabled) {
            clearAutoFailover();
        }
        log.info("MongoDB Standby Force Failover Mode changed: {} -> {}", previous, enabled);
    }

    public boolean isAutoFailoverActive() {
        long until = autoFailoverUntilEpochMs.get();
        return until > 0L && System.currentTimeMillis() < until;
    }

    public boolean isFailoverActive() {
        return isForceFailoverEnabled() || isAutoFailoverActive();
    }

    public String getEffectiveReadSource() {
        return isFailoverActive() ? SOURCE_MONGO_STANDBY : SOURCE_POSTGRES;
    }

    public void recordPostgresFailure(Throwable error) {
        long until = System.currentTimeMillis() + AUTO_FAILOVER_COOLDOWN_MS;
        autoFailoverUntilEpochMs.set(until);
        log.warn("PostgreSQL unavailable ({}), activating MongoDB Read-Fallback circuit for {}s",
                error != null ? error.getClass().getSimpleName() : "unknown",
                AUTO_FAILOVER_COOLDOWN_MS / 1000);
    }

    public void clearAutoFailover() {
        autoFailoverUntilEpochMs.set(0L);
    }

    /**
     * Thực thi thao tác đọc ưu tiên PostgreSQL, tự động chuyển hướng sang đọc từ 5 Collection
     * {@code pg_backup_*} trên MongoDB nếu đang bật chế độ Failover hoặc khi PostgreSQL mất kết nối.
     */
    public <T> T executeReadWithFallback(Supplier<T> postgresRead,
                                         Supplier<T> mongoFallback,
                                         String operationName) {
        if (isFailoverActive()) {
            log.debug("Serving [{}] from MongoDB Standby (failover active)", operationName);
            return mongoFallback.get();
        }
        try {
            return postgresRead.get();
        } catch (RuntimeException ex) {
            if (isPostgresUnavailableException(ex)) {
                recordPostgresFailure(ex);
                log.warn("Fallback to MongoDB Standby triggered for [{}]: {}", operationName, ex.toString());
                return mongoFallback.get();
            }
            throw ex;
        }
    }

    /**
     * Phân biệt lỗi mất kết nối/hạ tầng PostgreSQL với các lỗi nghiệp vụ thông thường (400/403/404).
     */
    public boolean isPostgresUnavailableException(Throwable throwable) {
        Throwable cursor = throwable;
        int depth = 0;
        while (cursor != null && depth < 12) {
            if (cursor instanceof CannotCreateTransactionException
                    || cursor instanceof DataAccessResourceFailureException
                    || cursor instanceof TransientDataAccessException
                    || cursor instanceof QueryTimeoutException
                    || cursor instanceof TransactionSystemException
                    || cursor instanceof SQLTransientException
                    || cursor instanceof ConnectException
                    || cursor instanceof SocketException) {
                return true;
            }
            if (cursor instanceof SQLException sqlEx) {
                String sqlState = sqlEx.getSQLState();
                // 08xxx: Connection Exception, 57Pxx: Operator Intervention (admin_shutdown, crash_shutdown, cannot_connect_now)
                if (sqlState != null && (sqlState.startsWith("08") || sqlState.startsWith("57P") || sqlState.startsWith("53"))) {
                    return true;
                }
            }
            String className = cursor.getClass().getName();
            if (className.contains("JDBCConnectionException") || className.contains("HikariPool")) {
                return true;
            }
            cursor = cursor.getCause();
            depth++;
        }
        return false;
    }
}
