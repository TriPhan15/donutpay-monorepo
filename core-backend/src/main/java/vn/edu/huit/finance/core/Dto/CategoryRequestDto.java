package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/** Form of POST /admin/ajax/categories (name and type as request parameters, sent by the admin categories page). */
@Getter
@Setter
public class CategoryRequestDto {

    public static final int NAME_MAX_LENGTH = 50;
    private static final String TYPE_REGEX = "INCOME|EXPENSE";

    @NotBlank(message = "Tên danh mục không được để trống")
    @Size(max = NAME_MAX_LENGTH, message = "Tên danh mục tối đa {max} ký tự")
    private String name;

    @NotBlank(message = "Loại danh mục không được để trống")
    @Pattern(regexp = TYPE_REGEX, message = "Loại danh mục chỉ được là INCOME hoặc EXPENSE")
    private String type;
}