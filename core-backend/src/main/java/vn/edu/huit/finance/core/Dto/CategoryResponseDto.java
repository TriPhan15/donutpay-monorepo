package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Data;
import vn.edu.huit.finance.core.Entity.Category;

@Data
@Builder
public class CategoryResponseDto {
    private Long id;
    private String name;
    private String type;

    public static CategoryResponseDto from(Category category) {
        return CategoryResponseDto.builder()
                .id(category.getId())
                .name(category.getName())
                .type(category.getType())
                .build();
    }
}