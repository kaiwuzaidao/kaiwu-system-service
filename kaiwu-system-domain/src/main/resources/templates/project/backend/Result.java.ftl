package ${basePackage}.common;

import java.util.Map;

/**
 * 统一响应外壳，与 Kaiwu 平台协议保持一致。
 *
 * <p>{@code message} 是服务端语言的安全消息，始终存在，便于日志检索和排查；
 * {@code messageKey} 是稳定的错误标识，前端据此翻译成当前界面语言。前端优先用 key，
 * 缺 key 时回退 message——新增语言不必改后端，服务端日志也不随界面语言变化。</p>
 */
public record Result<T>(
        int code,
        String message,
        String messageKey,
        Map<String, Object> messageArgs,
        T data
) {

    public Result {
        messageArgs = messageArgs == null ? null : Map.copyOf(messageArgs);
    }

    public static <T> Result<T> ok(T data) {
        return new Result<>(0, "ok", null, null, data);
    }

    public static <T> Result<T> error(int code, String message) {
        return new Result<>(code, message, null, null, null);
    }

    /**
     * @param messageKey  稳定错误标识，如 {@code error.order.notFound}
     * @param messageArgs 插值参数，只放可安全展示的值，禁止放 token、密码或内部堆栈
     */
    public static <T> Result<T> error(
            int code, String message, String messageKey, Map<String, Object> messageArgs
    ) {
        return new Result<>(code, message, messageKey, messageArgs, null);
    }
}
