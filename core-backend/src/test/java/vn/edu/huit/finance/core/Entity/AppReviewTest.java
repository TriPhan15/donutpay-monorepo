package vn.edu.huit.finance.core.Entity;

import org.junit.jupiter.api.Test;

import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.mockito.Mockito.mock;

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
        AtomicBoolean touched = new AtomicBoolean(false);
        User user = new User() {
            @Override
            public String toString() {
                touched.set(true);
                return "user";
            }

            @Override
            public int hashCode() {
                touched.set(true);
                return 1;
            }
        };
        AppReview review = reviewOf(user);

        review.toString();
        review.hashCode();

        assertFalse(touched.get(), "toString/hashCode of the review must not reach the lazy user");
    }
}
