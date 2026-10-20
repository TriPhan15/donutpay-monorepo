package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.OcrRawLog;

import java.util.List;

public interface OcrRawLogRepository extends MongoRepository<OcrRawLog, String> {
    List<OcrRawLog> findByTransactionIdOrderByCreatedAtDesc(Long transactionId);
    List<OcrRawLog> findByAverageConfidenceScoreLessThan(Double threshold);
}

