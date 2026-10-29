package vn.edu.huit.finance.core.Exception;

/** 404: không có gói dịch vụ với id này. */
public class SubscriptionPlanNotFoundException extends RuntimeException {

    public SubscriptionPlanNotFoundException(String message) {
        super(message);
    }
}
