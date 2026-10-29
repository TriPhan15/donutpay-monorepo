package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class CreatePaymentRequestDto {

    // Khớp cột payment_orders: amount numeric(19,2), provider varchar(16), description varchar(255).
    private static final int AMOUNT_INTEGER_DIGITS = 17;
    private static final int AMOUNT_FRACTION_DIGITS = 2;
    private static final String MAX_AMOUNT = "1000000000";
    private static final int PROVIDER_MAX_LENGTH = 16;
    private static final int TYPE_MAX_LENGTH = 16;
    private static final int DESCRIPTION_MAX_LENGTH = 255;

    @NotNull(message = "type khong duoc rong")
    @Size(max = TYPE_MAX_LENGTH, message = "Loại giao dịch (type) tối đa {max} ký tự")
    private String type;

    @Size(max = PROVIDER_MAX_LENGTH, message = "Cổng thanh toán (provider) tối đa {max} ký tự")
    private String provider;

    @NotNull(message = "amount khong duoc rong")
    @DecimalMin(value = "1000", message = "So tien toi thieu 1.000")
    @DecimalMax(value = MAX_AMOUNT, message = "Số tiền tối đa mỗi lần là 1.000.000.000 VNĐ")
    @Digits(integer = AMOUNT_INTEGER_DIGITS, fraction = AMOUNT_FRACTION_DIGITS,
            message = "Số tiền chỉ được có tối đa {integer} chữ số nguyên và {fraction} chữ số thập phân")
    private BigDecimal amount;

    @Size(max = DESCRIPTION_MAX_LENGTH, message = "Mô tả tối đa {max} ký tự")
    private String description;
}
