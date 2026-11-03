package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.BackupRun;

import java.util.Optional;

public interface BackupRunRepository extends MongoRepository<BackupRun, String> {

    /** Lần sao lưu tự động kết thúc gần nhất, thành công hay thất bại. */
    Optional<BackupRun> findFirstByOrderByFinishedAtDesc();
}
