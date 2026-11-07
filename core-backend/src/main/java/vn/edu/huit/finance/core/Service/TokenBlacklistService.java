package vn.edu.huit.finance.core.Service;

import io.jsonwebtoken.ExpiredJwtException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import vn.edu.huit.finance.core.Document.Backup.PgBackupRevokedTokenDocument;
import vn.edu.huit.finance.core.Entity.RevokedToken;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupRevokedTokenRepository;
import vn.edu.huit.finance.core.Repository.RevokedTokenRepository;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyFailoverService;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.Date;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Blacklist of JWTs that were revoked before they expired (logout, password change). It lives in the database, so a
 * restart or a second instance does not bring a revoked token back to life. Only the SHA-256 of a token is stored, and
 * only until the token would have expired anyway.
 */
@Slf4j
@Service
@RequiredArgsConstructor(onConstructor_ = @Autowired)
public class TokenBlacklistService {

    private static final String HASH_ALGORITHM = "SHA-256";
    // Every day at 03:30: a revoked token is only worth remembering until it would have expired anyway.
    private static final String PURGE_CRON = "0 30 3 * * *";
    static final int MAX_RECENT_REVOKED_CACHE_SIZE = 10_000;

    private final RevokedTokenRepository revokedTokenRepository;
    private final JwtUtil jwtUtil;
    private final ObjectProvider<MongoStandbyFailoverService> failoverServiceProvider;
    private final ObjectProvider<PgBackupRevokedTokenRepository> backupRevokedTokenRepoProvider;

    private final ConcurrentHashMap<String, LocalDateTime> recentRevokedTokens = new ConcurrentHashMap<>();

    // Not injected: production uses the system clock; tests replace it to control time.
    private Clock clock = Clock.systemDefaultZone();

    public TokenBlacklistService() {
        this(null, null, null, null);
    }

    /** Revokes a token the caller has already verified. Revoking the same token twice is harmless. */
    @Transactional
    public void revoke(String token) {
        Date expiration;
        try {
            expiration = jwtUtil.extractExpiration(token);
        } catch (ExpiredJwtException e) {
            // Expired between the check of the caller and now: it cannot be used any more, so there is nothing to store.
            log.debug("Token expired while it was being revoked");
            return;
        }

        String hash = fingerprint(token);
        LocalDateTime now = LocalDateTime.now(clock);
        LocalDateTime expiresAt = LocalDateTime.ofInstant(expiration.toInstant(), clock.getZone());

        MongoStandbyFailoverService failover = failoverService();
        if (failover != null && failover.isFailoverActive()) {
            rememberInMemory(hash, expiresAt, now);
            mirrorToMongo(hash, expiresAt, now);
            log.info("Token revoked in standby mode, expiresAt={}", expiresAt);
            return;
        }

        try {
            if (revokedTokenRepository.existsByTokenHash(hash)) {
                registerAfterCommit(hash, expiresAt, now);
                return;
            }
            revokedTokenRepository.save(new RevokedToken(hash, expiresAt, now));
            registerAfterCommit(hash, expiresAt, now);
            log.info("Token revoked, expiresAt={}", expiresAt);
        } catch (RuntimeException e) {
            if (failover != null && failover.isPostgresUnavailableException(e)) {
                failover.recordPostgresFailure(e);
                rememberInMemory(hash, expiresAt, now);
                mirrorToMongo(hash, expiresAt, now);
                log.warn("Token revoked in MongoDB standby because PostgreSQL is unreachable, expiresAt={}", expiresAt);
                return;
            }
            throw e;
        }
    }

    /** For a token the client supplied: one that is garbage or expired cannot be used anyway, so it is skipped. */
    @Transactional
    public void revokeIfValid(String token) {
        if (jwtUtil.validateToken(token)) {
            revoke(token);
        } else {
            log.debug("Token is invalid or expired, nothing to revoke");
        }
    }

    /** Asked for every authenticated request, so it is one indexed lookup; checks MongoDB standby when PostgreSQL is down. */
    @Transactional(readOnly = true, propagation = Propagation.SUPPORTS)
    public boolean isRevoked(String token) {
        String hash = fingerprint(token);
        LocalDateTime now = LocalDateTime.now(clock);
        if (isRememberedInMemory(hash, now)) {
            return true;
        }
        MongoStandbyFailoverService failover = failoverService();
        if (failover != null && failover.isFailoverActive()) {
            return isRevokedInMongo(hash, now);
        }
        try {
            return revokedTokenRepository.existsByTokenHash(hash);
        } catch (RuntimeException e) {
            if (failover != null && failover.isPostgresUnavailableException(e)) {
                failover.recordPostgresFailure(e);
                log.warn("TokenBlacklistService switched to MongoDB standby check because PostgreSQL is unreachable");
                return isRevokedInMongo(hash, now);
            }
            throw e;
        }
    }

    @Scheduled(cron = PURGE_CRON)
    @Transactional
    public void purgeExpired() {
        LocalDateTime now = LocalDateTime.now(clock);
        purgeExpiredInMemory(now);
        int removed = revokedTokenRepository.deleteExpiredBefore(now);
        PgBackupRevokedTokenRepository backupRepo = backupRevokedTokenRepo();
        if (backupRepo != null) {
            try {
                backupRepo.deleteByExpiresAtBefore(now);
            } catch (RuntimeException e) {
                log.warn("Failed to purge expired revoked tokens from MongoDB standby: {}", e.getMessage());
            }
        }
        log.info("Purged {} revoked tokens that have expired", removed);
    }

    /** Clears the in-memory cache (used by tests to simulate a server restart during failover). */
    public void clearInMemoryCache() {
        recentRevokedTokens.clear();
    }

    private void registerAfterCommit(String hash, LocalDateTime expiresAt, LocalDateTime revokedAt) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    rememberInMemory(hash, expiresAt, LocalDateTime.now(clock));
                    mirrorToMongo(hash, expiresAt, revokedAt);
                }
            });
        } else {
            rememberInMemory(hash, expiresAt, LocalDateTime.now(clock));
            mirrorToMongo(hash, expiresAt, revokedAt);
        }
    }

    private void rememberInMemory(String hash, LocalDateTime expiresAt, LocalDateTime now) {
        if (!expiresAt.isAfter(now)) {
            recentRevokedTokens.remove(hash);
            return;
        }
        if (recentRevokedTokens.size() >= MAX_RECENT_REVOKED_CACHE_SIZE && !recentRevokedTokens.containsKey(hash)) {
            purgeExpiredInMemory(now);
            if (recentRevokedTokens.size() >= MAX_RECENT_REVOKED_CACHE_SIZE) {
                recentRevokedTokens.entrySet().stream()
                        .min(Comparator.comparing(Map.Entry::getValue))
                        .map(Map.Entry::getKey)
                        .ifPresent(recentRevokedTokens::remove);
            }
        }
        recentRevokedTokens.put(hash, expiresAt);
    }

    private boolean isRememberedInMemory(String hash, LocalDateTime now) {
        LocalDateTime expiresAt = recentRevokedTokens.get(hash);
        if (expiresAt == null) {
            return false;
        }
        if (!expiresAt.isAfter(now)) {
            recentRevokedTokens.remove(hash, expiresAt);
            return false;
        }
        return true;
    }

    private void purgeExpiredInMemory(LocalDateTime cutoff) {
        recentRevokedTokens.entrySet().removeIf(entry -> !entry.getValue().isAfter(cutoff));
    }

    private void mirrorToMongo(String hash, LocalDateTime expiresAt, LocalDateTime revokedAt) {
        PgBackupRevokedTokenRepository backupRepo = backupRevokedTokenRepo();
        if (backupRepo == null) {
            return;
        }
        try {
            backupRepo.save(PgBackupRevokedTokenDocument.builder()
                    .tokenHash(hash)
                    .expiresAt(expiresAt)
                    .revokedAt(revokedAt)
                    .mirroredAt(LocalDateTime.now(clock))
                    .build());
        } catch (RuntimeException e) {
            log.warn("Failed to mirror revoked token to MongoDB standby: {}", e.getMessage());
        }
    }

    private boolean isRevokedInMongo(String hash, LocalDateTime now) {
        PgBackupRevokedTokenRepository backupRepo = backupRevokedTokenRepo();
        if (backupRepo == null) {
            return false;
        }
        try {
            boolean revoked = backupRepo.existsByTokenHashAndExpiresAtAfter(hash, now);
            return revoked;
        } catch (RuntimeException e) {
            log.warn("Failed to query revoked token in MongoDB standby: {}", e.getMessage());
            return false;
        }
    }

    private MongoStandbyFailoverService failoverService() {
        return failoverServiceProvider != null ? failoverServiceProvider.getIfAvailable() : null;
    }

    private PgBackupRevokedTokenRepository backupRevokedTokenRepo() {
        return backupRevokedTokenRepoProvider != null ? backupRevokedTokenRepoProvider.getIfAvailable() : null;
    }

    private static String fingerprint(String token) {
        try {
            byte[] digest = MessageDigest.getInstance(HASH_ALGORITHM).digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            // Every JVM has to provide SHA-256, so this cannot happen.
            throw new IllegalStateException(HASH_ALGORITHM + " is not available", e);
        }
    }
}
