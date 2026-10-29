package vn.edu.huit.finance.core.Controller;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.UserResponseDto;
import vn.edu.huit.finance.core.Dto.UserUpdateDto;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.UserService;

@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private CurrentUserProvider currentUserProvider;

    @Autowired
    private UserService userService;

    // Hàm tiện ích map Entity sang DTO
    private UserResponseDto mapToDto(User u) {
        return UserResponseDto.builder()
                .id(u.getId())
                .username(u.getUsername())
                .email(u.getEmail())
                .phone(u.getPhone())
                .role(u.getRole())
                .walletBalance(u.getWalletBalance())
                .build();
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserResponseDto>> me() {
        User u = currentUserProvider.getCurrentUser();
        ApiResponse<UserResponseDto> response = ApiResponse.<UserResponseDto>builder()
                .code(200)
                .message("OK")
                .data(mapToDto(u))
                .build();
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<UserResponseDto>> updateProfile(
            @PathVariable Long id,
            @Valid @RequestBody UserUpdateDto dto) {

        // UserService refuses (403) an id that is not the caller's, and records the update (USER_UPDATED) in its transaction.
        User updatedUser = userService.updateOwnProfile(currentUserProvider.getCurrentUser(), id, dto);

        ApiResponse<UserResponseDto> response = ApiResponse.<UserResponseDto>builder()
                .code(200)
                .message("Cập nhật thông tin cá nhân thành công!")
                .data(mapToDto(updatedUser))
                .build();
        return ResponseEntity.ok(response);
    }
}