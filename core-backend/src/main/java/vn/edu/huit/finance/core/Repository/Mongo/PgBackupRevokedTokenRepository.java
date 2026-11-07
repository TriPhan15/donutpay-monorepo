package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.Backup.PgBackupRevokedTokenDocument;

import java.time.LocalDateTime;

public interface PgBackupRevokedTokenRepository extends MongoRepository<PgBackupRevokedTokenDocument, String> {

    boolean existsByTokenHashAndExpiresAtAfter(String tokenHash, LocalDateTime now);

    long deleteByExpiresAtBefore(LocalDateTime cutoff);
}
