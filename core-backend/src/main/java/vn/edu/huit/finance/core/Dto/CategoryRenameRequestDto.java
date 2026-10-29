package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/** Form of PUT /admin/ajax/categories/{id}: the new name only (the type of a category never changes). */
@Getter
@Setter
public class CategoryRenameRequestDto {

    @NotBlank(message = "Tên danh mục không được để trống")
    @Size(max = CategoryRequestDto.NAME_MAX_LENGTH, message = "Tên danh mục tối đa {max} ký tự")
    private String name;
}