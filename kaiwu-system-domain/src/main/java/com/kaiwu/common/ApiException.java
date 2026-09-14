package com.kaiwu.common;

import java.util.Map;
import org.springframework.http.HttpStatus;

/**
 * 平台管理 API 的明确业务错误。
 */
public final class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String messageKey;
    private final Map<String, Object> messageArgs;

    public ApiException(HttpStatus status, String message, String messageKey) {
        this(status, message, messageKey, null);
    }

    public ApiException(HttpStatus status, String message, String messageKey, Map<String, Object> messageArgs) {
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
