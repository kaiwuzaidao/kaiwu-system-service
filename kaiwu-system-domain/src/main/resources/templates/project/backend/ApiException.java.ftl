package ${basePackage}.common;

import org.springframework.http.HttpStatus;

import java.util.Map;

/**
 * 业务异常。
 *
 * <p>抛出时**必须带上 messageKey**，前端才能把错误翻译成用户的界面语言：
 *
 * <pre>{@code
 * throw new ApiException(HttpStatus.NOT_FOUND, "订单不存在",
 *         "error.order.notFound", Map.of("orderNo", orderNo));
 * }</pre>
 *
 * <p>{@code message} 保持服务端语言不变，它服务于日志与排查；只有 key 参与界面翻译。
 * {@code messageArgs} 只放可安全展示的值，禁止放 token、密码、连接串或内部堆栈。</p>
 */
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String messageKey;
    private final Map<String, Object> messageArgs;

    public ApiException(HttpStatus status, String message, String messageKey) {
        this(status, message, messageKey, null);
    }

    public ApiException(
            HttpStatus status, String message,
            String messageKey, Map<String, Object> messageArgs
    ) {
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
