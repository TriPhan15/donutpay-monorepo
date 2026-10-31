package vn.edu.huit.finance.core.Dto;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** A12: the admin plan editor's body, as Jackson reads it and as @Valid checks it. */
class SubscriptionPlanRequestDtoTest {

    private static final ObjectMapper JSON = new ObjectMapper();
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

    private static String body(String flagKey, boolean flag, String price, int days, int scans, String name) {
        return "{\"planName\":\"" + name + "\",\"price\":" + price + ",\"durationDays\":" + days + ",\"maxAiScans\":" + scans
                + ",\"" + flagKey + "\":" + flag + "}";
    }

    private static Set<String> invalidFields(SubscriptionPlanRequestDto dto) {
        return validator.validate(dto).stream().map(ConstraintViolation::getPropertyPath).map(Object::toString)
                .collect(Collectors.toSet());
    }

    @ParameterizedTest
    @ValueSource(strings = {"wcmSpadeEnabled", "isWcmSpadeEnabled"})
    void theWcmSpadeFlagIsReadUnderTheNewKeyAndTheOldOne(String key) throws Exception {
        assertTrue(JSON.readValue(body(key, true, "99000", 30, 100, "VIP"), SubscriptionPlanRequestDto.class).isWcmSpadeEnabled());
        assertFalse(JSON.readValue(body(key, false, "99000", 30, 100, "VIP"), SubscriptionPlanRequestDto.class).isWcmSpadeEnabled());
    }

    @Test
    void aUsualPlanIsValid() throws Exception {
        assertTrue(invalidFields(JSON.readValue(body("wcmSpadeEnabled", true, "99000", 30, 100, "VIP"),
                SubscriptionPlanRequestDto.class)).isEmpty());
    }

    @Test
    void aNegativePriceAnEmptyNameAndNegativeScansAreRefused() throws Exception {
        SubscriptionPlanRequestDto dto = JSON.readValue(body("wcmSpadeEnabled", true, "-1", 0, -5, " "),
                SubscriptionPlanRequestDto.class);

        assertEquals(Set.of("planName", "price", "durationDays", "maxAiScans"), invalidFields(dto));
    }

    @Test
    void missingNumbersAreRefused() {
        SubscriptionPlanRequestDto dto = SubscriptionPlanRequestDto.builder().planName("VIP").build();

        assertEquals(Set.of("price", "durationDays", "maxAiScans"), invalidFields(dto));
    }
}
