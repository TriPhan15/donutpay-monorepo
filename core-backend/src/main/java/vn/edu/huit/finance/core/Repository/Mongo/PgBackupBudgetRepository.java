package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.Backup.PgBackupBudgetDocument;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PgBackupBudgetRepository extends MongoRepository<PgBackupBudgetDocument, Long> {

    List<PgBackupBudgetDocument> findByUserIdOrderByStartDateDescIdDesc(Long userId);

    Optional<PgBackupBudgetDocument> findByIdAndUserId(Long id, Long userId);

    void deleteByIdNotIn(Collection<Long> ids);
}
