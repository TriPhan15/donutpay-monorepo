package vn.edu.huit.finance.core.Exception;

/**
 * The AI service could not be reached or gave no usable answer. The message is a fixed text that may be shown to a
 * client; the cause stays on the server, in the log line of the caller.
 */
public class AiServiceUnavailableException extends RuntimeException {

    public AiServiceUnavailableException(String message) {
        super(message);
    }

    public AiServiceUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
