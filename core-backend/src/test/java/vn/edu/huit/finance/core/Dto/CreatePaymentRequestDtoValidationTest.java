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

import java.math.BigDecimal;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** POST /api/payments/create: amount, provider and description fit the columns of payment_orders (A11). */
class CreatePaymentRequestDtoValidationTest {

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

    private static CreatePaymentRequestDto dto(String amount) {
        CreatePaymentRequestDto dto = new CreatePaymentRequestDto();
        dto.setType("DEPOSIT");
        dto.setProvider("VNPAY");
        dto.setAmount(new BigDecimal(amount));
        dto.setDescription("Nạp ví");
        return dto;
    }

    private static Set<String> invalidFields(CreatePaymentRequestDto dto) {
        return validator.validate(dto).stream().map(ConstraintViolation::getPropertyPath).map(Object::toString)
                .collect(Collectors.toSet());
    }

    @Test
    void aUsualDepositIsValid() {
        assertTrue(invalidFields(dto("100000")).isEmpty());
        assertTrue(invalidFields(dto("1000000000")).isEmpty());
    }

    @ParameterizedTest
    @ValueSource(strings = {"1000000000.01", "99999999999999999", "100000.555", "999"})
    void anAmountOutOfRangeOrWithThreeDecimalsIsInvalid(String amount) {
        assertEquals(Set.of("amount"), invalidFields(dto(amount)));
    }

    @Test
    void aProviderLongerThanItsColumnIsInvalid() {
        CreatePaymentRequestDto dto = dto("100000");
        dto.setProvider("P".repeat(17));
        assertEquals(Set.of("provider"), invalidFields(dto));
    }

    @Test
    void aDescriptionLongerThanItsColumnIsInvalid() {
        CreatePaymentRequestDto dto = dto("100000");
        dto.setDescription("d".repeat(256));
        assertEquals(Set.of("description"), invalidFields(dto));
    }
}
