package vn.edu.huit.finance.core.Exception;

/**
 * 409: another request created a category with the same name for the same owner at the same moment, so this one could not;
 * nothing was written. Sending the request again finds the category the other one created.
 */
public class CategoryNameTakenException extends RuntimeException {

    public CategoryNameTakenException(String message, Throwable cause) {
        super(message, cause);
    }
}
