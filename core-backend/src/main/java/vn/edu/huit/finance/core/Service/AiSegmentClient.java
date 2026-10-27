package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import vn.edu.huit.finance.core.Exception.AiServiceUnavailableException;
import vn.edu.huit.finance.core.Repository.UserRfmRow;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Gọi POST /admin/segment của dịch vụ AI. Mọi lỗi kết nối hoặc thiếu "segments" đều thành một câu 503 cố định. */
@Slf4j
@Component
public class AiSegmentClient {

    static final String MSG_AI_SERVICE_UNAVAILABLE = "Dịch vụ AI tạm thời không phản hồi, vui lòng thử lại sau.";
    private static final String AI_SEGMENT_PATH = "/admin/segment";
    private static final String USERS_KEY = "users";
    private static final String AI_SEGMENTS_KEY = "segments";
    private static final String USER_ID_KEY = "user_id";
    private static final String LABEL_KEY = "label";
    private static final String RECENCY_KEY = "recency";
    private static final String FREQUENCY_KEY = "frequency";
    private static final String MONETARY_KEY = "monetary";

    /** Một nhóm do AI trả về, chưa kiểm tra: userId và label có thể null hoặc lạ. */
    public record SegmentAssignment(String userId, String label) {
    }

    /** Base URL of the AI service; env AI_SERVICE_URL, by default the docker-compose service name. */
    @Value("${app.ai-service.url:${AI_SERVICE_URL:http://data-mining-api:8000}}")
    private String aiServiceUrl;

    @SuppressWarnings("unchecked")
    public List<SegmentAssignment> requestSegments(List<UserRfmRow> rows) {
        List<Map<String, Object>> users = new ArrayList<>();
        for (UserRfmRow row : rows) {
            Map<String, Object> user = new LinkedHashMap<>();
            user.put(USER_ID_KEY, String.valueOf(row.getUserId()));
            user.put(RECENCY_KEY, row.getRecency());
            user.put(FREQUENCY_KEY, row.getFrequency());
            user.put(MONETARY_KEY, row.getMonetary());
            users.add(user);
        }

        String url = aiServiceUrl + AI_SEGMENT_PATH;
        ResponseEntity<Map> response;
        try {
            response = new RestTemplate().postForEntity(url, Map.of(USERS_KEY, users), Map.class);
        } catch (RestClientException e) {
            log.error("AI segmentation call to {} failed", url, e);
            throw new AiServiceUnavailableException(MSG_AI_SERVICE_UNAVAILABLE, e);
        }
        Object segments = response.getBody() == null ? null : response.getBody().get(AI_SEGMENTS_KEY);
        if (!response.getStatusCode().is2xxSuccessful() || !(segments instanceof List)) {
            log.error("AI segmentation call to {} returned no segments, status={}", url, response.getStatusCode());
            throw new AiServiceUnavailableException(MSG_AI_SERVICE_UNAVAILABLE);
        }
        List<SegmentAssignment> assignments = new ArrayList<>();
        for (Object item : (List<Object>) segments) {
            if (!(item instanceof Map)) {
                log.error("AI segmentation call to {} returned an entry that is not an object", url);
                throw new AiServiceUnavailableException(MSG_AI_SERVICE_UNAVAILABLE);
            }
            Map<String, Object> entry = (Map<String, Object>) item;
            assignments.add(new SegmentAssignment(asText(entry.get(USER_ID_KEY)), asText(entry.get(LABEL_KEY))));
        }
        return assignments;
    }

    private static String asText(Object value) {
        return value == null ? null : value.toString();
    }
}
