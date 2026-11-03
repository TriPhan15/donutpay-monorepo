package vn.edu.huit.finance.core.Exception;

/** A sign-up asked for an email or a username that another account already has. The message names which. */
public class AccountAlreadyExistsException extends RuntimeException {

    public AccountAlreadyExistsException(String message) {
        super(message);
    }
}
