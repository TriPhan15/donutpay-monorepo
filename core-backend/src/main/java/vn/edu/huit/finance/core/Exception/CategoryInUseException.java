package vn.edu.huit.finance.core.Exception;

/** 409: danh mục còn được giao dịch hoặc ngân sách dùng nên không xóa được; không có gì bị xóa. */
public class CategoryInUseException extends RuntimeException {

    public CategoryInUseException(String message) {
        super(message);
    }
}
