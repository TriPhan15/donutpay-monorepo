package vn.edu.huit.finance.core.Dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import vn.edu.huit.finance.core.Entity.User;

/**
 * An account as the admin pages receive it after creating or updating one (the JSON data of /admin/ajax/users): these
 * five keys and no others, the lock flag under the name {@code isActive} the page scripts read.
 */
public record AdminUserResponseDto(
        Long id,
        String username,
        String email,
        String role,
        @JsonProperty("isActive") boolean isActive) {

    public static AdminUserResponseDto from(User user) {
        return new AdminUserResponseDto(user.getId(), user.getUsername(), user.getEmail(), user.getRole(), user.isActive());
    }
}
