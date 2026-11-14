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

    /**
     * 创建没有插值参数的业务异常。
     *
     * @param status 对外 HTTP 状态
     * @param message 仅含安全信息的服务端语言消息
     * @param messageKey 前端翻译使用的稳定错误标识
     */
    public ApiException(HttpStatus status, String message, String messageKey) {
        this(status, message, messageKey, null);
    }

    /**
     * 创建带安全插值参数的业务异常。
     *
     * @param status 对外 HTTP 状态
     * @param message 仅含安全信息的服务端语言消息
     * @param messageKey 前端翻译使用的稳定错误标识
     * @param messageArgs 可安全展示的插值参数
     */
    public ApiException(
            HttpStatus status, String message,
            String messageKey, Map<String, Object> messageArgs
    ) {
        super(message);
        this.status = status;
        this.messageKey = messageKey;
        this.messageArgs = messageArgs == null ? null : Map.copyOf(messageArgs);
    }

    /**
     * 返回需要写入 HTTP 响应的状态。
     *
     * @return 对外 HTTP 状态
     */
    public HttpStatus getStatus() {
        return status;
    }

    /**
     * 返回用于前端国际化的稳定错误标识。
     *
     * @return 错误标识
     */
    public String getMessageKey() {
        return messageKey;
    }

    /**
     * 返回可安全展示的国际化插值参数。
     *
     * @return 插值参数；没有参数时为空
     */
    public Map<String, Object> getMessageArgs() {
        return messageArgs;
    }
}
