package vn.edu.huit.finance.core.Dto;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import vn.edu.huit.finance.core.Util.ImageUrls;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** B7(b): the extra receipt images of a checkout are a short list of https links, the same rule as the main image. */
class TransactionRequestDtoImagesTest {

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

    private static Set<String> invalidFields(List<String> additionalImages) {
        TransactionRequestDto dto = new TransactionRequestDto();
        dto.setAmount(new BigDecimal("50000"));
        dto.setLocation("Highlands");
        dto.setPaymentMethod("Tiền mặt");
        dto.setTransactionDate(LocalDateTime.of(2026, 10, 31, 9, 0));
        dto.setAdditionalImages(additionalImages);
        return validator.validate(dto).stream().map(ConstraintViolation::getPropertyPath).map(Object::toString)
                .collect(Collectors.toSet());
    }

    @Test
    void noImagesAFewHttpsLinksAndTheLimitItselfAreAccepted() {
        assertTrue(invalidFields(null).isEmpty());
        assertTrue(invalidFields(List.of()).isEmpty());
        assertTrue(invalidFields(List.of("https://cdn.example.com/a.jpg", "HTTPS://cdn.example.com/b.png")).isEmpty());
        assertTrue(invalidFields(Collections.nCopies(ImageUrls.MAX_ADDITIONAL_IMAGES, "https://cdn.example.com/a.jpg"))
                .isEmpty());
    }

    @Test
    void moreImagesThanTheLimitAreRefused() {
        assertEquals(Set.of("additionalImages"),
                invalidFields(Collections.nCopies(ImageUrls.MAX_ADDITIONAL_IMAGES + 1, "https://cdn.example.com/a.jpg")));
    }

    @Test
    void aLinkLongerThanTheColumnOfTheMainImageIsRefused() {
        String tooLong = "https://cdn.example.com/" + "a".repeat(ImageUrls.MAX_LENGTH);
        assertEquals(1, invalidFields(List.of(tooLong)).size());
    }

    @ParameterizedTest
    @ValueSource(strings = {"http://cdn.example.com/a.jpg", "javascript:alert(1)", "data:text/html;base64,AAAA",
            "//cdn.example.com/a.jpg", "https://cdn example.com/a.jpg", "", "   "})
    void aLinkThatIsNotHttpsOrIsBlankIsRefused(String link) {
        List<String> images = new ArrayList<>(List.of("https://cdn.example.com/ok.jpg"));
        images.add(link);
        Set<String> invalid = invalidFields(images);
        assertEquals(1, invalid.size(), invalid.toString());
        assertTrue(invalid.iterator().next().startsWith("additionalImages"), invalid.toString());
    }

    @Test
    void aNullElementIsRefused() {
        List<String> images = new ArrayList<>();
        images.add(null);
        assertEquals(1, invalidFields(images).size());
    }
}
