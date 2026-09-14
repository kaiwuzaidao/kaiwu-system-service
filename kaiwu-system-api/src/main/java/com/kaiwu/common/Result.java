package com.kaiwu.common;

import java.util.Map;

/**
 * 平台统一响应。
 *
 * <p>HTTP 状态表达协议结果，code 与 HTTP 状态保持一致；成功固定为 0。</p>
 */
public record Result<T>(int code, String message, String messageKey, Map<String, Object> messageArgs, T data) {

    public Result {
        messageArgs = messageArgs == null ? null : Map.copyOf(messageArgs);
    }

    /** 保留旧构造器，避免一次性破坏现有调用方。 */
    public Result(int code, String message, T data) {
        this(code, message, null, null, data);
    }

    public static <T> Result<T> ok(T data) {
        return new Result<>(0, "ok", null, null, data);
    }

    public static <T> Result<T> error(int code, String message) {
        return new Result<>(code, message, null, null, null);
    }

    public static <T> Result<T> error(int code, String message, String messageKey, Map<String, Object> messageArgs) {
        return new Result<>(code, message, messageKey, messageArgs, null);
    }
}
