package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import vn.edu.huit.finance.core.Entity.CustomerSegment;
import vn.edu.huit.finance.core.Exception.AiServiceUnavailableException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Repository.UserRfmRow;
import vn.edu.huit.finance.core.Service.AiSegmentClient.SegmentAssignment;
import vn.edu.huit.finance.core.Util.SavingsContributions;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Phân lớp khách hàng: tính RFM chuẩn (chỉ khoản chi, 12 tháng gần nhất), nhờ dịch vụ AI gán nhóm, rồi ghi mọi nhãn
 * trong MỘT giao dịch. Câu trả lời sai (user_id null/lạ/trùng, nhãn lạ) bị từ chối nguyên khối, không ghi gì.
 */
@Slf4j
@Service
public class CustomerSegmentationService {

    static final int RFM_WINDOW_MONTHS = 12;
    static final int NO_ACTIVITY_DAYS = 366;

    // Không inject: chạy thật dùng đồng hồ hệ thống; test thay để cố định thời gian.
    private Clock clock = Clock.systemDefaultZone();

    @Autowired private UserRepository userRepository;
    @Autowired private AiSegmentClient aiSegmentClient;
    @Autowired private TransactionTemplate transactionTemplate;

    /**
     * Trả số người dùng được gán nhãn. Cuộc gọi HTTP tới AI chạy NGOÀI mọi giao dịch (không giữ kết nối DB trong lúc
     * chờ); chỉ bước ghi nhãn nằm trong một giao dịch duy nhất.
     */
    public int runSegmentation() {
        LocalDateTime now = LocalDateTime.now(clock);
        List<UserRfmRow> rows = userRepository.calculateAllUsersRfm(
                now.minusMonths(RFM_WINDOW_MONTHS), now, SavingsContributions.CATEGORY_NAME, NO_ACTIVITY_DAYS);
        Set<Long> sentIds = new HashSet<>();
        for (UserRfmRow row : rows) {
            sentIds.add(row.getUserId());
        }

        Map<CustomerSegment, Set<Long>> idsBySegment = validate(aiSegmentClient.requestSegments(rows), sentIds);

        Integer assigned = transactionTemplate.execute(status -> {
            int count = 0;
            for (Map.Entry<CustomerSegment, Set<Long>> entry : idsBySegment.entrySet()) {
                userRepository.updateAiLabelForUsers(entry.getKey().name(), entry.getValue());
                count += entry.getValue().size();
            }
            return count;
        });
        int total = assigned == null ? 0 : assigned;
        if (total != rows.size()) {
            log.warn("AI segmentation answered {} of {} users", total, rows.size());
        }
        return total;
    }

    /** Số người dùng theo nhóm, đủ mọi nhóm theo thứ tự enum (nhóm vắng là 0); nhãn cũ hoặc lạ bị bỏ qua. */
    @Transactional(readOnly = true)
    public Map<CustomerSegment, Long> countBySegment() {
        Map<CustomerSegment, Long> counts = new LinkedHashMap<>();
        for (CustomerSegment segment : CustomerSegment.values()) {
            counts.put(segment, 0L);
        }
        for (Object[] row : userRepository.countUsersByAiLabel()) {
            CustomerSegment.fromCode((String) row[0])
                    .ifPresent(segment -> counts.put(segment, ((Number) row[1]).longValue()));
        }
        return counts;
    }

    private Map<CustomerSegment, Set<Long>> validate(List<SegmentAssignment> assignments, Set<Long> sentIds) {
        Map<CustomerSegment, Set<Long>> idsBySegment = new EnumMap<>(CustomerSegment.class);
        Set<Long> seen = new HashSet<>();
        for (SegmentAssignment assignment : assignments) {
            Long userId = parseUserId(assignment.userId());
            CustomerSegment segment = CustomerSegment.fromCode(assignment.label()).orElse(null);
            if (userId == null || !sentIds.contains(userId) || !seen.add(userId) || segment == null) {
                log.error("AI segmentation answer rejected: user_id={}, label={}", assignment.userId(), assignment.label());
                throw new AiServiceUnavailableException(AiSegmentClient.MSG_AI_SERVICE_UNAVAILABLE);
            }
            idsBySegment.computeIfAbsent(segment, key -> new HashSet<>()).add(userId);
        }
        return idsBySegment;
    }

    private static Long parseUserId(String text) {
        if (text == null || text.isEmpty() || !text.chars().allMatch(c -> c >= '0' && c <= '9')) {
            return null;
        }
        try {
            return Long.valueOf(text);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
