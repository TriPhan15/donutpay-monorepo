package vn.edu.huit.finance.core.Exception;

/** 404: không có mục tiêu tiết kiệm với id này. */
public class SavingGoalNotFoundException extends RuntimeException {

    public SavingGoalNotFoundException(String message) {
        super(message);
    }
}
