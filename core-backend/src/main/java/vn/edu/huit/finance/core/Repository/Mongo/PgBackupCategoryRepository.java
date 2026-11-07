package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;
import vn.edu.huit.finance.core.Document.Backup.PgBackupCategoryDocument;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PgBackupCategoryRepository extends MongoRepository<PgBackupCategoryDocument, Long> {

    /**
     * Danh mục mặc định (ownerId == null) và danh mục riêng của người dùng (ownerId == userId).
     */
    @Query("{ '$or': [ { 'ownerId': null }, { 'ownerId': ?0 } ] }")
    List<PgBackupCategoryDocument> findVisibleToUser(Long userId);

    Optional<PgBackupCategoryDocument> findTopByOrderByIdDesc();

    void deleteByIdNotIn(Collection<Long> ids);
}
