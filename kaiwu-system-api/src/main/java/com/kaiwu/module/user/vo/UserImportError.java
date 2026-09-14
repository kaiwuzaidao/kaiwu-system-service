package com.kaiwu.module.user.vo;

import java.util.Map;

public record UserImportError(
        int rowNumber, String username, String message, String messageKey, Map<String, Object> messageArgs) {
    public UserImportError {
        messageArgs = messageArgs == null ? null : Map.copyOf(messageArgs);
    }

    public UserImportError(int rowNumber, String username, String message) {
        this(rowNumber, username, message, null, null);
    }
}
