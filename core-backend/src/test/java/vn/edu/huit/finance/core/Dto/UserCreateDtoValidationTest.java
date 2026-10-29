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

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Mật khẩu admin đặt cho người dùng mới theo cùng chính sách @StrongPassword như đăng ký và đổi mật khẩu (A2). */
class UserCreateDtoValidationTest {

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

    private static UserCreateDto dto(String password) {
        UserCreateDto dto = new UserCreateDto();
        dto.setUsername("newuser");
        dto.setEmail("newuser@example.com");
        dto.setPhone("0900000001");
        dto.setPassword(password);
        dto.setRole("ROLE_USER");
        return dto;
    }

    private static boolean passwordRejected(String password) {
        Set<ConstraintViolation<UserCreateDto>> violations = validator.validate(dto(password));
        return violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("password"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"secret1", "1234567", "abcdefgh", "12345678", "        "})
    void aWeakPasswordIsRejected(String password) {
        assertTrue(passwordRejected(password), password);
    }

    @Test
    void aPasswordLongerThanBcryptReadsIsRejected() {
        assertTrue(passwordRejected("a1" + "x".repeat(71)));
    }

    @Test
    void aStrongPasswordIsAccepted() {
        assertFalse(passwordRejected("secret123"));
        assertTrue(validator.validate(dto("secret123")).isEmpty());
    }
}
