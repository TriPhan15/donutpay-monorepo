package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import vn.edu.huit.finance.core.Security.StrongPassword;

@Data
public class UserCreateDto {
    @NotBlank(message = "Username is required")
    private String username;

    @NotBlank(message = "Email is required")
    @Email(message = "Email is invalid")
    private String email;

    @NotBlank(message = "Số điện thoại không được để trống")
    private String phone;

    // Cùng chính sách với đăng ký và đổi mật khẩu (tối thiểu 8 ký tự, có chữ và số).
    @StrongPassword
    private String password;

    @NotBlank(message = "Role is required")
    private String role;
}