package vn.edu.huit.finance.core.Repository.Mongo;

import org.springframework.data.mongodb.repository.Aggregation;
import org.springframework.data.mongodb.repository.MongoRepository;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Dto.MongoErrorStatsDto;

import java.util.List;

public interface OcrFeedbackRepository extends MongoRepository<OcrFeedback, String> {
    List<OcrFeedback> findByIsResolvedFalse();

    @Aggregation("{ $group: { _id: '$fieldError', count: { $sum: 1 } } }")
    List<MongoErrorStatsDto> countErrorsByField();
}
