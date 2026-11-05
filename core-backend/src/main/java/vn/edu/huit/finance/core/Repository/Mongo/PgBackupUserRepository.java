package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.Backup.PgBackupUserDocument;

import java.util.Collection;
import java.util.Optional;

public interface PgBackupUserRepository extends MongoRepository<PgBackupUserDocument, Long> {

    Optional<PgBackupUserDocument> findByEmailIgnoreCase(String email);

    Optional<PgBackupUserDocument> findByUsernameIgnoreCase(String username);

    void deleteByIdNotIn(Collection<Long> ids);
}
