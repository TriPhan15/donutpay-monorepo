package vn.edu.huit.finance.core.Controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Exception.ReindexInProgressException;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Search.TransactionSearchIndexer;

/**
 * Upkeep of the Elasticsearch index of the transactions. Closed to everybody without ROLE_ADMIN by the /api/admin/** rule
 * of SecurityConfig and again by @PreAuthorize. The indexer only exists with {@code app.search.engine=elasticsearch}:
 * without it every call is a 503.
 */
@Slf4j
@RestController
@RequestMapping("/api/admin/search")
@PreAuthorize(Roles.HAS_ADMIN)
public class AdminSearchController {

    static final String MSG_REINDEX_OK = "Đã dựng lại chỉ mục tìm kiếm từ cơ sở dữ liệu";
    static final String MSG_SEARCH_DISABLED = "Tìm kiếm Elasticsearch đang tắt";
    static final String MSG_REINDEX_FAILED = "Không dựng lại được chỉ mục tìm kiếm, vui lòng thử lại sau";

    private final ObjectProvider<TransactionSearchIndexer> indexer;

    public AdminSearchController(ObjectProvider<TransactionSearchIndexer> indexer) {
        this.indexer = indexer;
    }

    /** Drops the index and builds it again from PostgreSQL; the number of transactions indexed. */
    @PostMapping("/reindex")
    public ResponseEntity<ApiResponse<Integer>> reindex() {
        TransactionSearchIndexer available = indexer.getIfAvailable();
        if (available == null) {
            return ApiResponses.respond(HttpStatus.SERVICE_UNAVAILABLE, MSG_SEARCH_DISABLED, null);
        }
        try {
            return ApiResponses.respond(HttpStatus.OK, MSG_REINDEX_OK, available.reindexAll());
        } catch (ReindexInProgressException e) {
            return ApiResponses.respond(HttpStatus.CONFLICT, e.getMessage(), null);
        } catch (DataAccessException e) {
            log.warn("Search reindex failed", e);
            return ApiResponses.respond(HttpStatus.SERVICE_UNAVAILABLE, MSG_REINDEX_FAILED, null);
        }
    }
}
