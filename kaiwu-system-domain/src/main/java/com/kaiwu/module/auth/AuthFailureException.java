package com.kaiwu.module.auth;

import java.util.Map;
import org.springframework.http.HttpStatus;

/**
 * 可映射为明确 HTTP 状态的认证失败。
 */
public final class AuthFailureException extends RuntimeException {

    private final HttpStatus status;
    private final String messageKey;
    private final Map<String, Object> messageArgs;

    public AuthFailureException(HttpStatus status, String message, String messageKey) {
        this(status, message, messageKey, null);
    }

    public AuthFailureException(HttpStatus status, String message, String messageKey, Map<String, Object> messageArgs) {
        super(message);
        this.status = status;
        this.messageKey = messageKey;
        this.messageArgs = messageArgs == null ? null : Map.copyOf(messageArgs);
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getMessageKey() {
        return messageKey;
    }

    public Map<String, Object> getMessageArgs() {
        return messageArgs;
    }
}
