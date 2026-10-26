package vn.edu.huit.finance.core.Repository;
import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.huit.finance.core.Entity.Category;

import java.util.Optional;

public interface CategoryRepository  extends JpaRepository<Category, Long> {
    /** Tìm theo tên không phân biệt hoa thường; nếu dữ liệu cũ có tên trùng thì lấy danh mục tạo sớm nhất. */
    Optional<Category> findFirstByNameIgnoreCaseOrderByIdAsc(String name);
}
