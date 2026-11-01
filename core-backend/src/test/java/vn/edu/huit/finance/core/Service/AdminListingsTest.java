package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import vn.edu.huit.finance.core.Entity.AppReview;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.SubscriptionPlan;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.AppReviewRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.ReceiptRepository;
import vn.edu.huit.finance.core.Repository.SubscriptionPlanRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The reads the admin pages make through the services instead of the repositories: each returns what the repository
 * returns, and the users come newest first (highest id first).
 */
@ExtendWith(MockitoExtension.class)
class AdminListingsTest {

    @Mock private UserRepository userRepository;
    @Mock private CategoryRepository categoryRepository;
    @Mock private ReceiptRepository receiptRepo;
    @Mock private SubscriptionPlanRepository subscriptionPlanRepository;
    @Mock private AppReviewRepository appReviewRepository;

    @InjectMocks private UserService userService;
    @InjectMocks private CategoryService categoryService;
    @InjectMocks private ReceiptProcessingService receiptProcessingService;
    @InjectMocks private SubscriptionPlanService subscriptionPlanService;
    @InjectMocks private AppReviewService appReviewService;

    @Test
    void usersAreListedNewestFirstInTheRequestedPage() {
        Page<User> page = new PageImpl<>(List.of(new User()));
        when(userRepository.findAll(any(Pageable.class))).thenReturn(page);

        assertSame(page, userService.listNewestFirst(PageRequest.of(2, 15)));

        verify(userRepository).findAll(PageRequest.of(2, 15, Sort.by(Sort.Direction.DESC, "id")));
    }

    @Test
    void categoriesAreAllListed() {
        List<Category> categories = List.of(new Category());
        when(categoryRepository.findAll()).thenReturn(categories);

        assertEquals(categories, categoryService.listAll());
    }

    @Test
    void plansAreAllListed() {
        List<SubscriptionPlan> plans = List.of(new SubscriptionPlan());
        when(subscriptionPlanRepository.findAll()).thenReturn(plans);

        assertEquals(plans, subscriptionPlanService.listAll());
    }

    @Test
    void receiptsAreListedNewestFirstInTheRequestedPage() {
        Page<Receipt> page = new PageImpl<>(List.of(new Receipt()));
        Pageable pageable = PageRequest.of(1, 5);
        when(receiptRepo.findAllByOrderByCreatedAtDesc(pageable)).thenReturn(page);

        assertSame(page, receiptProcessingService.listNewestFirst(pageable));
    }

    @Test
    void reviewsAreListedNewestFirst() {
        List<AppReview> reviews = List.of(new AppReview());
        when(appReviewRepository.findAllByOrderByCreatedAtDesc()).thenReturn(reviews);

        assertEquals(reviews, appReviewService.listNewestFirst());
    }
}
