package vn.edu.huit.finance.core.Service.Search;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import vn.edu.huit.finance.core.Config.SearchEngineType;
import vn.edu.huit.finance.core.Dto.TransactionSearchRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchResponseDto;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class TransactionSearchServiceTest {

    private static final long USER_ID = 7L;
    private static final String QUERY = "phở";

    private CurrentUserProvider currentUser;
    private TransactionRepository transactionRepo;
    private ElasticsearchTransactionSearchEngine elasticsearch;
    private PostgresTransactionSearchEngine postgres;

    @BeforeEach
    void setUp() {
        currentUser = mock(CurrentUserProvider.class);
        transactionRepo = mock(TransactionRepository.class);
        elasticsearch = mock(ElasticsearchTransactionSearchEngine.class);
        postgres = mock(PostgresTransactionSearchEngine.class);
        User caller = new User();
        caller.setId(USER_ID);
        when(currentUser.getCurrentUser()).thenReturn(caller);
    }

    private TransactionSearchService service(SearchEngineType type) {
        return new TransactionSearchService(currentUser, transactionRepo, type, postgres,
                type == SearchEngineType.ELASTICSEARCH ? Optional.of(elasticsearch) : Optional.empty());
    }

    private static TransactionSearchRequestDto request(String q) {
        TransactionSearchRequestDto request = new TransactionSearchRequestDto();
        request.setQ(q);
        request.setPage(1);
        request.setSize(5);
        return request;
    }

    private static Transaction row(long id) {
        Transaction transaction = new Transaction();
        transaction.setId(id);
        transaction.setNote("giao dịch " + id);
        transaction.setCategoryName("Ăn uống");
        transaction.setAmount(new BigDecimal("1000"));
        transaction.setTransactionDate(LocalDateTime.of(2026, 10, 1, 12, 0));
        return transaction;
    }

    @Test
    void esHitsReloadedFromPostgres_inHitOrder() {
        when(elasticsearch.hits(eq(USER_ID), eq(QUERY), any(Pageable.class)))
                .thenReturn(new TransactionSearchEngine.SearchHits(List.of(3L, 1L, 2L), 13));
        when(transactionRepo.findAllByIdInAndUserIdWithReceipt(anyCollection(), eq(USER_ID)))
                .thenReturn(List.of(row(1), row(2), row(3)));

        TransactionSearchResponseDto response = service(SearchEngineType.ELASTICSEARCH).search(request(QUERY));

        assertEquals(List.of(3L, 1L, 2L), response.getItems().stream().map(i -> i.getId()).toList());
        assertEquals(13, response.getTotal());
        assertEquals("elasticsearch", response.getEngine());
        verify(elasticsearch).hits(USER_ID, QUERY, PageRequest.of(1, 5));
    }

    @Test
    void idMissingInPostgres_dropped() {
        when(elasticsearch.hits(anyLong(), any(), any()))
                .thenReturn(new TransactionSearchEngine.SearchHits(List.of(1L, 99L, 2L), 3));
        when(transactionRepo.findAllByIdInAndUserIdWithReceipt(anyCollection(), eq(USER_ID)))
                .thenReturn(List.of(row(2), row(1)));

        TransactionSearchResponseDto response = service(SearchEngineType.ELASTICSEARCH).search(request(QUERY));

        assertEquals(List.of(1L, 2L), response.getItems().stream().map(i -> i.getId()).toList());
    }

    @Test
    void esThrows_fallsBackToPostgres_engineIsPostgres() {
        when(elasticsearch.hits(anyLong(), any(), any())).thenThrow(new IllegalStateException("es down"));
        when(postgres.hits(eq(USER_ID), eq(QUERY), any(Pageable.class)))
                .thenReturn(new TransactionSearchEngine.SearchHits(List.of(5L), 1));
        when(transactionRepo.findAllByIdInAndUserIdWithReceipt(anyCollection(), eq(USER_ID)))
                .thenReturn(List.of(row(5)));

        TransactionSearchResponseDto response = service(SearchEngineType.ELASTICSEARCH).search(request(QUERY));

        assertEquals("postgres", response.getEngine());
        assertEquals(List.of(5L), response.getItems().stream().map(i -> i.getId()).toList());
    }

    @Test
    void engineConfiguredPostgres_neverCallsEs() {
        when(postgres.hits(anyLong(), any(), any())).thenReturn(new TransactionSearchEngine.SearchHits(List.of(), 0));

        TransactionSearchResponseDto response = service(SearchEngineType.POSTGRES).search(request(QUERY));

        assertEquals("postgres", response.getEngine());
        assertEquals(0, response.getItems().size());
        verifyNoInteractions(elasticsearch);
        verify(transactionRepo, never()).findAllByIdInAndUserIdWithReceipt(any(), anyLong());
    }

    @Test
    void userIdComesFromCurrentUserProvider() {
        when(postgres.hits(anyLong(), any(), any())).thenReturn(new TransactionSearchEngine.SearchHits(List.of(), 0));

        service(SearchEngineType.POSTGRES).search(request("  " + QUERY + "  "));

        verify(currentUser).getCurrentUser();
        verify(postgres).hits(USER_ID, QUERY, PageRequest.of(1, 5));
    }
}
