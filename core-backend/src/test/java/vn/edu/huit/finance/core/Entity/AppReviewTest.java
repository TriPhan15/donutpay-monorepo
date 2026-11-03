package vn.edu.huit.finance.core.Entity;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

/** The review keeps identity equality and a toString/hashCode that never walk into the lazy user. */
class AppReviewTest {

    private static AppReview reviewOf(User user) {
        AppReview review = new AppReview();
        review.setId(1L);
        review.setUser(user);
        review.setUserEmail("a@example.com");
        review.setRating(5);
        review.setComment("Tốt");
        return review;
    }

    @Test
    void twoReviewsWithTheSameFieldsAreNotEqual() {
        User user = mock(User.class);
        assertNotEquals(reviewOf(user), reviewOf(user));
    }

    @Test
    void toStringAndHashCodeDoNotTouchTheUser() {
        User user = mock(User.class);
        AppReview review = reviewOf(user);

        review.toString();
        review.hashCode();

        verifyNoInteractions(user);
    }
}
