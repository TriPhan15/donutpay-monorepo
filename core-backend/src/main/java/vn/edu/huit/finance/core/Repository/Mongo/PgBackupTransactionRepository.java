package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.Backup.PgBackupTransactionDocument;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PgBackupTransactionRepository extends MongoRepository<PgBackupTransactionDocument, Long> {

    List<PgBackupTransactionDocument> findByUserIdOrderByTransactionDateDescIdDesc(Long userId);

    List<PgBackupTransactionDocument> findByIdInAndUserId(Collection<Long> ids, Long userId);

    Optional<PgBackupTransactionDocument> findByReceipt_Id(Long receiptId);

    Optional<PgBackupTransactionDocument> findTopByOrderByIdDesc();

    Optional<PgBackupTransactionDocument> findTopByReceipt_IdIsNotNullOrderByReceipt_IdDesc();

    void deleteByIdNotIn(Collection<Long> ids);
}
