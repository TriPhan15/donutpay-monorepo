package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Service.AiSegmentClient.SegmentAssignment;

import java.util.Collection;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;

/**
 * Nhãn ghi qua proxy @Transactional thật, lệnh UPDATE thứ hai hỏng: nhãn của nhóm thứ nhất cũng phải hoàn lại, vì
 * toàn bộ lần chạy nằm trong một giao dịch.
 */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@Import(CustomerSegmentationService.class)
class CustomerSegmentationRollbackTest {

    private static final String OLD_LABEL = "OLD";

    @Autowired private CustomerSegmentationService service;
    @Autowired private JdbcTemplate jdbc;
    @SpyBean private UserRepository userRepo;
    @MockBean private AiSegmentClient client;

    private Long aliceId;
    private Long bobId;

    @BeforeEach
    void setUp() {
        aliceId = persist("alice", "0900000001");
        bobId = persist("bob", "0900000002");
    }

    @AfterEach
    void cleanUp() {
        userRepo.deleteAll();
    }

    private Long persist(String name, String phone) {
        User user = new User();
        user.setUsername(name);
        user.setEmail(name + "@example.com");
        user.setPhone(phone);
        user.setPassword("hash");
        user.setAiLabel(OLD_LABEL);
        return userRepo.saveAndFlush(user).getId();
    }

    private List<String> labelsInDatabase() {
        return jdbc.queryForList("select ai_label from users order by id", String.class);
    }

    @Test
    void aFailureOnTheSecondSegmentLeavesEveryLabelAsItWas() {
        when(client.requestSegments(any())).thenReturn(List.of(
                new SegmentAssignment(aliceId.toString(), "CHAMPIONS"), new SegmentAssignment(bobId.toString(), "LOST")));
        // A spy on a Spring Data repository cannot call the real method: the first call writes the same rows by JDBC, in
        // the transaction of the service, and the second one fails.
        AtomicInteger calls = new AtomicInteger();
        doAnswer(invocation -> {
            if (calls.incrementAndGet() > 1) {
                throw new DataAccessResourceFailureException("x");
            }
            Collection<?> ids = invocation.getArgument(1);
            return jdbc.update("update users set ai_label = ? where id in (" + ids.stream().map(String::valueOf)
                    .collect(Collectors.joining(",")) + ")", (String) invocation.getArgument(0));
        }).when(userRepo).updateAiLabelForUsers(any(), any());

        assertThrows(DataAccessException.class, service::runSegmentation);

        assertEquals(List.of(OLD_LABEL, OLD_LABEL), labelsInDatabase());
    }

    @Test
    void noTransactionIsActiveWhileTheAiServiceIsCalled() {
        AtomicBoolean active = new AtomicBoolean(true);
        when(client.requestSegments(any())).thenAnswer(invocation -> {
            active.set(TransactionSynchronizationManager.isActualTransactionActive());
            return List.of(new SegmentAssignment(aliceId.toString(), "CHAMPIONS"));
        });

        service.runSegmentation();

        assertFalse(active.get());
    }

    @Test
    void aGoodAnswerWritesEveryLabel() {
        when(client.requestSegments(any())).thenReturn(List.of(
                new SegmentAssignment(aliceId.toString(), "CHAMPIONS"), new SegmentAssignment(bobId.toString(), "LOST")));

        assertEquals(2, service.runSegmentation());

        assertEquals(List.of("CHAMPIONS", "LOST"), labelsInDatabase());
    }

    @Test
    void aUserTheAiLeftOutLosesTheOldLabel() {
        when(client.requestSegments(any())).thenReturn(List.of(new SegmentAssignment(aliceId.toString(), "CHAMPIONS")));

        assertEquals(1, service.runSegmentation());

        assertEquals(java.util.Arrays.asList("CHAMPIONS", null), labelsInDatabase());
    }
}
