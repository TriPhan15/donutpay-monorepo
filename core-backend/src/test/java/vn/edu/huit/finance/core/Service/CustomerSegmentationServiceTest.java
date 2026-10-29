package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Entity.CustomerSegment;
import vn.edu.huit.finance.core.Exception.AiServiceUnavailableException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Repository.UserRfmRow;
import vn.edu.huit.finance.core.Service.AiSegmentClient.SegmentAssignment;

import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomerSegmentationServiceTest {

    private static final LocalDateTime NOW = LocalDateTime.parse("2026-10-28T10:00");
    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    @Mock private UserRepository userRepo;
    @Mock private AiSegmentClient client;
    @InjectMocks private CustomerSegmentationService service;

    private List<UserRfmRow> rows;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "transactionTemplate",
                new TransactionTemplate(org.mockito.Mockito.mock(PlatformTransactionManager.class)));
        ReflectionTestUtils.setField(service, "clock", Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE));
        rows = List.of(row(1L), row(2L), row(3L));
        lenient().when(userRepo.calculateAllUsersRfm(any(), any(), anyString(), anyInt())).thenReturn(rows);
    }

    private static UserRfmRow row(long id) {
        return new UserRfmRow() {
            public Long getUserId() { return id; }
            public Integer getRecency() { return 3; }
            public Long getFrequency() { return 5L; }
            public BigDecimal getMonetary() { return BigDecimal.TEN; }
        };
    }

    private void aiAnswers(SegmentAssignment... answer) {
        when(client.requestSegments(rows)).thenReturn(new ArrayList<>(List.of(answer)));
    }

    private void assertRejectedAndNothingWritten() {
        assertThrows(AiServiceUnavailableException.class, service::runSegmentation);
        verify(userRepo, never()).updateAiLabelForUsers(any(), any());
        verify(userRepo, never()).clearAiLabelForUsers(any());
    }

    @Test
    void asksForTwelveMonthsOfExpensesWithoutSavings() {
        aiAnswers();

        service.runSegmentation();

        verify(userRepo).calculateAllUsersRfm(LocalDateTime.parse("2025-10-28T10:00"), NOW, "Tiết kiệm", 366);
    }

    @Test
    void writesOneUpdatePerSegment() {
        aiAnswers(new SegmentAssignment("1", "CHAMPIONS"), new SegmentAssignment("2", "CHAMPIONS"),
                new SegmentAssignment("3", "LOST"));

        int count = service.runSegmentation();

        verify(userRepo).updateAiLabelForUsers("CHAMPIONS", Set.of(1L, 2L));
        verify(userRepo).updateAiLabelForUsers("LOST", Set.of(3L));
        verify(userRepo, never()).clearAiLabelForUsers(any());
        assertEquals(3, count);
    }

    @Test
    void aPartialAnswer_clearsTheLabelsOfUsersLeftOut() {
        aiAnswers(new SegmentAssignment("1", "LOYAL"), new SegmentAssignment("2", "LOST"));

        int count = service.runSegmentation();

        verify(userRepo).updateAiLabelForUsers("LOYAL", Set.of(1L));
        verify(userRepo).updateAiLabelForUsers("LOST", Set.of(2L));
        verify(userRepo).clearAiLabelForUsers(Set.of(3L));
        assertEquals(2, count);
    }

    @Test
    void anAnswerWithANullUserId_isRejected_andNothingIsWritten() {
        aiAnswers(new SegmentAssignment("1", "LOYAL"), new SegmentAssignment(null, "LOYAL"));
        assertRejectedAndNothingWritten();
    }

    @Test
    void aUserIdThatIsNotANumber_isRejected() {
        aiAnswers(new SegmentAssignment("1", "LOYAL"), new SegmentAssignment("abc", "LOYAL"));
        assertRejectedAndNothingWritten();
    }

    @Test
    void anAnswerNamingAUserThatWasNotSent_isRejected_andNothingIsWritten() {
        aiAnswers(new SegmentAssignment("1", "LOYAL"), new SegmentAssignment("99", "LOYAL"));
        assertRejectedAndNothingWritten();
    }

    @Test
    void anAnswerWithADuplicateUser_isRejected() {
        aiAnswers(new SegmentAssignment("1", "LOYAL"), new SegmentAssignment("1", "LOST"));
        assertRejectedAndNothingWritten();
    }

    @Test
    void anUnknownLabel_isRejected() {
        aiAnswers(new SegmentAssignment("1", "LOYAL"), new SegmentAssignment("2", "VIP"));
        assertRejectedAndNothingWritten();
    }

    @Test
    void countBySegment_listsEverySegmentInOrder_withZeros_andSkipsOldLabels() {
        when(userRepo.countUsersByAiLabel()).thenReturn(List.of(
                new Object[]{"LOST", 4L}, new Object[]{"CHAMPIONS", 2L}, new Object[]{"VIP", 9L}));

        Map<CustomerSegment, Long> counts = service.countBySegment();

        assertEquals(List.of(CustomerSegment.values()), List.copyOf(counts.keySet()));
        assertEquals(2L, counts.get(CustomerSegment.CHAMPIONS));
        assertEquals(4L, counts.get(CustomerSegment.LOST));
        assertEquals(0L, counts.get(CustomerSegment.LOYAL));
        assertEquals(6L, counts.values().stream().mapToLong(Long::longValue).sum());
    }
}
