package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.Backup.PgBackupSavingGoalDocument;

import java.util.Collection;
import java.util.List;

public interface PgBackupSavingGoalRepository extends MongoRepository<PgBackupSavingGoalDocument, Long> {

    List<PgBackupSavingGoalDocument> findByUserIdOrderByCreatedAtDesc(Long userId);

    void deleteByIdNotIn(Collection<Long> ids);
}
