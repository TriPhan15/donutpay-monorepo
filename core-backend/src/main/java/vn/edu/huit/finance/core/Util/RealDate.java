package vn.edu.huit.finance.core.Util;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.format.ResolverStyle;
import java.util.regex.Pattern;

/**
 * Một ngày có thật theo dạng dd/MM/yyyy. Chỉ kiểm dạng chữ thì "99/99/9999" hay "31/02/2026" vẫn lọt, nên chuỗi còn
 * được parse chặt bằng {@link LocalDate}. Null được chấp nhận (không có hạn); thêm {@code @NotNull} nếu bắt buộc.
 */
@Documented
@Constraint(validatedBy = RealDate.Validator.class)
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
public @interface RealDate {

    String message() default "Ngày phải có dạng dd/MM/yyyy và có thật";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

    class Validator implements ConstraintValidator<RealDate, String> {

        private static final Pattern SHAPE = Pattern.compile("^\\d{2}/\\d{2}/\\d{4}$");
        private static final DateTimeFormatter STRICT_DATE =
                DateTimeFormatter.ofPattern("dd/MM/uuuu").withResolverStyle(ResolverStyle.STRICT);

        @Override
        public boolean isValid(String value, ConstraintValidatorContext context) {
            if (value == null) {
                return true;
            }
            if (!SHAPE.matcher(value).matches()) {
                return false;
            }
            try {
                LocalDate.parse(value, STRICT_DATE);
                return true;
            } catch (DateTimeParseException invalidDate) {
                return false;
            }
        }
    }
}
