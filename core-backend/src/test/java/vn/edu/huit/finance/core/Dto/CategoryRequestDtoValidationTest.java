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

import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** A13: the admin category forms take a name of 1-50 characters and a type of INCOME or EXPENSE only. */
class CategoryRequestDtoValidationTest {

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

    private static CategoryRequestDto create(String name, String type) {
        CategoryRequestDto dto = new CategoryRequestDto();
        dto.setName(name);
        dto.setType(type);
        return dto;
    }

    private static <T> Set<String> invalidFields(T dto) {
        return validator.validate(dto).stream().map(ConstraintViolation::getPropertyPath).map(Object::toString)
                .collect(Collectors.toSet());
    }

    @ParameterizedTest
    @ValueSource(strings = {"INCOME", "EXPENSE"})
    void aNamedCategoryOfEitherTypeIsValid(String type) {
        assertTrue(invalidFields(create("Cà phê", type)).isEmpty());
    }

    @Test
    void aBlankOrLongNameAndAnUnknownTypeAreRefused() {
        assertEquals(Set.of("name", "type"), invalidFields(create(" ", "FOO")));
        assertEquals(Set.of("name"), invalidFields(create("x".repeat(51), "EXPENSE")));
        assertEquals(Set.of("type"), invalidFields(create("Cà phê", "expense ")));
    }

    @Test
    void aRenameNeedsANameOfAtMost50Characters() {
        CategoryRenameRequestDto rename = new CategoryRenameRequestDto();
        rename.setName("");
        assertEquals(Set.of("name"), invalidFields(rename));
        rename.setName("x".repeat(50));
        assertTrue(invalidFields(rename).isEmpty());
    }
}
