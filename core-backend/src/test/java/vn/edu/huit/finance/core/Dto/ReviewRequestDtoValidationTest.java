package vn.edu.huit.finance.core.Dto;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** A15: the comment of a review is bounded (the column is TEXT, so nothing else stops a huge one). */
class ReviewRequestDtoValidationTest {

    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll
    static void setUp() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void tearDown() {
        factory.close();
    }

    private static ReviewRequestDto review(String comment) {
        ReviewRequestDto dto = new ReviewRequestDto();
        dto.setRating(5);
        dto.setComment(comment);
        return dto;
    }

    @Test
    void aCommentOf1000CharactersIsAccepted() {
        assertTrue(validator.validate(review("c".repeat(1000))).isEmpty());
    }

    @Test
    void aLongerCommentIsRefused() {
        assertEquals(1, validator.validate(review("c".repeat(1001))).size());
    }
}
