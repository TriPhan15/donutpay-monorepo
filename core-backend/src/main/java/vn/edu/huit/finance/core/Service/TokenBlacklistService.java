package vn.edu.huit.finance.core.Service;

import io.jsonwebtoken.ExpiredJwtException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Entity.RevokedToken;
import vn.edu.huit.finance.core.Repository.RevokedTokenRepository;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyFailoverService;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Date;
import java.util.HexFormat;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Blacklist of JWTs that were revoked before they expired (logout, password change). It lives in the database, so a
 * restart or a second instance does not bring a revoked token back to life. Only the SHA-256 of a token is stored, and
 * only until the token would have expired anyway.
 */
@Slf4j
@Service
public class TokenBlacklistService {

    private static final String HASH_ALGORITHM = "SHA-256";
    // Every day at 03:30: a revoked token is only worth remembering until it would have expired anyway.
    private static final String PURGE_CRON = "0 30 3 * * *";

    @Autowired
    private RevokedTokenRepository revokedTokenRepository;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired(required = false)
    private MongoStandbyFailoverService failoverService;

    private final Set<String> recentRevokedHashes = ConcurrentHashMap.newKeySet();

    // Not injected: production uses the system clock; tests replace it to control time.
    private Clock clock = Clock.systemDefaultZone();

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
        recentRevokedHashes.add(hash);
        if (revokedTokenRepository.existsByTokenHash(hash)) {
            return;
        }
        LocalDateTime expiresAt = LocalDateTime.ofInstant(expiration.toInstant(), clock.getZone());
        revokedTokenRepository.save(new RevokedToken(hash, expiresAt, LocalDateTime.now(clock)));
        log.info("Token revoked, expiresAt={}", expiresAt);
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

    /** Asked for every authenticated request, so it is one indexed lookup; gracefully degrades when PostgreSQL is down. */
    @Transactional(readOnly = true, propagation = Propagation.SUPPORTS)
    public boolean isRevoked(String token) {
        String hash = fingerprint(token);
        if (recentRevokedHashes.contains(hash)) {
            return true;
        }
        if (failoverService != null && failoverService.isFailoverActive()) {
            return false;
        }
        try {
            return revokedTokenRepository.existsByTokenHash(hash);
        } catch (RuntimeException e) {
            if (failoverService != null && failoverService.isPostgresUnavailableException(e)) {
                failoverService.recordPostgresFailure(e);
                log.warn("TokenBlacklistService degraded to in-memory check because PostgreSQL is unreachable");
                return false;
            }
            throw e;
        }
    }

    @Scheduled(cron = PURGE_CRON)
    @Transactional
    public void purgeExpired() {
        int removed = revokedTokenRepository.deleteExpiredBefore(LocalDateTime.now(clock));
        log.info("Purged {} revoked tokens that have expired", removed);
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
