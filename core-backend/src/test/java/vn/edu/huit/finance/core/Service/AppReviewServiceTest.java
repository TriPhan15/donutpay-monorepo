package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vn.edu.huit.finance.core.Exception.AppReviewNotFoundException;
import vn.edu.huit.finance.core.Dto.ReviewRequestDto;
import vn.edu.huit.finance.core.Entity.AppReview;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.UserNotFoundException;
import vn.edu.huit.finance.core.Repository.AppReviewRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;

import java.util.NoSuchElementException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** App reviews: submitted as the caller of the request; moderation decisions each with its row, by the administrator. */
@ExtendWith(MockitoExtension.class)
class AppReviewServiceTest {

    @Mock private AppReviewRepository repository;
    @Mock private AuditLogService auditLogService;
    @Mock private CurrentUserProvider currentUserProvider;
    @InjectMocks private AppReviewService service;

    private AppReview review() {
        AppReview review = new AppReview();
        review.setId(4L);
        review.setUserEmail("alice@example.com");
        review.setComment("Tuyệt vời <b>");
        when(repository.findById(4L)).thenReturn(Optional.of(review));
        return review;
    }

    private AuditEntry recorded() {
        ArgumentCaptor<AuditEntry> entry = ArgumentCaptor.forClass(AuditEntry.class);
        verify(auditLogService).record(entry.capture());
        return entry.getValue();
    }

    @Test
    void anApprovalIsRecordedWithTheReviewer_notTheComment() {
        AppReview review = review();

        service.approveReview(4L);

        assertEquals(AppReviewService.STATUS_APPROVED, review.getStatus());
        AuditEntry entry = recorded();
        assertEquals(AuditAction.REVIEW_APPROVED, entry.action());
        assertEquals(AuditActor.currentCaller(), entry.actor());
        assertEquals(4L, entry.targetId());
        assertEquals("Duyệt hiển thị đánh giá của: alice@example.com", entry.description());
        assertFalse(entry.description().contains("Tuyệt vời"));
    }

    @Test
    void aDeletionIsRecorded() {
        AppReview review = review();

        service.deleteReview(4L);

        verify(repository).delete(review);
        assertEquals(AuditAction.REVIEW_DELETED, recorded().action());
    }

    @Test
    void aReviewThatDoesNotExistIsRefused_andNothingIsRecorded() {
        when(repository.findById(5L)).thenReturn(Optional.empty());

        assertThrows(AppReviewNotFoundException.class, () -> service.approveReview(5L));

        verifyNoInteractions(auditLogService);
    }

    private ReviewRequestDto reviewRequest() {
        ReviewRequestDto request = new ReviewRequestDto();
        request.setRating(5);
        request.setComment("Ứng dụng dễ dùng");
        return request;
    }

    @Test
    void aSubmittedReviewBelongsToTheCallerFromTheJwt_andWaitsForModeration() {
        User caller = new User();
        caller.setId(11L);
        caller.setEmail("bob@example.com");
        when(currentUserProvider.getCurrentUser()).thenReturn(caller);

        service.submitMyReview(reviewRequest());

        ArgumentCaptor<AppReview> saved = ArgumentCaptor.forClass(AppReview.class);
        verify(repository).save(saved.capture());
        AppReview review = saved.getValue();
        assertSame(caller, review.getUser());
        assertEquals("bob@example.com", review.getUserEmail());
        assertEquals(5, review.getRating());
        assertEquals("Ứng dụng dễ dùng", review.getComment());
        assertEquals(AppReviewService.STATUS_PENDING, review.getStatus());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void withoutAKnownCallerNothingIsSaved() {
        when(currentUserProvider.getCurrentUser()).thenThrow(new UserNotFoundException("Không tìm thấy người dùng đang đăng nhập"));

        assertThrows(UserNotFoundException.class, () -> service.submitMyReview(reviewRequest()));

        verify(repository, never()).save(any());
    }
}
