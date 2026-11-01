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

/** B7(a): the deadline of a savings goal has to be a real calendar date in dd/MM/yyyy, not just look like one. */
class SavingGoalDtoValidationTest {

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

    private static Set<String> invalidFields(String deadline) {
        SavingGoalDto dto = SavingGoalDto.builder().title("Mua xe").target(new BigDecimal("50000000"))
                .deadline(deadline).build();
        return validator.validate(dto).stream().map(ConstraintViolation::getPropertyPath).map(Object::toString)
                .collect(Collectors.toSet());
    }

    @ParameterizedTest
    @ValueSource(strings = {"30/06/2027", "29/02/2028", "01/01/2026"})
    void aRealDateIsAccepted(String deadline) {
        assertTrue(invalidFields(deadline).isEmpty());
    }

    @Test
    void noDeadlineIsAccepted() {
        // The app leaves the deadline out when the user clears it.
        assertTrue(invalidFields(null).isEmpty());
    }

    @ParameterizedTest
    @ValueSource(strings = {"99/99/9999", "31/02/2026", "29/02/2027", "00/01/2026", "31/04/2026", "2027-06-30", "1/1/2027", ""})
    void aDateThatDoesNotExistOrHasAnotherShapeIsRefused(String deadline) {
        assertEquals(Set.of("deadline"), invalidFields(deadline));
    }
}
