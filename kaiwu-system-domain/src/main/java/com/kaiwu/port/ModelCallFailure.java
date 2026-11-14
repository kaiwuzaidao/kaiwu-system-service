package com.kaiwu.port;

/**
 * 模型调用失败，并带上可统计的失败类别。
 *
 * <p>继承 {@link IllegalStateException} 且消息文案保持原样：连通性测试页
 * （{@code AiProviderController}）依赖该类型与文案回显诊断，Agent 编排依赖它归为
 * {@code PROVIDER_UNAVAILABLE}。类别只进入评估日志，用来回答「模型调用到底慢在哪、
 * 败在哪」——超时与连不上过去都报成同一句话，日志里无法区分。</p>
 *
 * <p>类别与 HTTP 状态码都不含凭据、提问或返回内容，可以直接写日志。</p>
 */
public class ModelCallFailure extends IllegalStateException {

    private final Category category;
    private final Integer httpStatus;

    public ModelCallFailure(Category category, String message, Throwable cause) {
        this(category, null, message, cause);
    }

    /**
     * @param httpStatus 模型服务返回的 HTTP 状态码；没有拿到响应时为 {@code null}
     */
    public ModelCallFailure(Category category, Integer httpStatus, String message, Throwable cause) {
        super(message, cause);
        this.category = category;
        this.httpStatus = httpStatus;
    }

    public Category category() {
        return category;
    }

    public Integer httpStatus() {
        return httpStatus;
    }

    /** 失败类别；顺序无意义，新增类别只能追加，日志与基线报告按名称统计。 */
    public enum Category {
        /** 出站网络策略（代理、白名单、协议）拒绝。 */
        NETWORK_POLICY,
        /** 建连失败（DNS、拒绝连接、证书等），未拿到响应。 */
        CONNECT,
        /** 请求超时，含建连超时与等待响应超时。 */
        TIMEOUT,
        /** HTTP 401 / 403。 */
        HTTP_AUTH,
        /** HTTP 404，多为地址缺少路径前缀或模型名不存在。 */
        HTTP_NOT_FOUND,
        /** HTTP 429。 */
        HTTP_RATE_LIMIT,
        /** 其余 HTTP 4xx。 */
        HTTP_4XX,
        /** HTTP 5xx。 */
        HTTP_5XX,
        /** 其余非 2xx 状态码。 */
        HTTP_OTHER,
        /** 响应体超过大小上限。 */
        RESPONSE_TOO_LARGE,
        /** 响应读取中途失败。 */
        RESPONSE_READ,
        /** 响应不是有效 JSON。 */
        INVALID_JSON,
        /** 返回了 JSON 但没有可用内容。 */
        EMPTY_CONTENT,
        /** 等待期间线程被中断。 */
        INTERRUPTED,
        /** 无法生成请求等本地错误。 */
        LOCAL_ERROR,
        /** 不是本类产生的异常，无法归类。 */
        UNKNOWN
    }

    /** 把任意异常归类；不是 {@link ModelCallFailure} 时返回 {@link Category#UNKNOWN}。 */
    public static Category categoryOf(Throwable failure) {
        for (Throwable cursor = failure; cursor != null; cursor = cursor.getCause()) {
            if (cursor instanceof ModelCallFailure classified) return classified.category;
        }
        return Category.UNKNOWN;
    }

    /** 取失败链上的 HTTP 状态码；不是 {@link ModelCallFailure} 或没有拿到响应时为 {@code null}。 */
    public static Integer statusOf(Throwable failure) {
        for (Throwable cursor = failure; cursor != null; cursor = cursor.getCause()) {
            if (cursor instanceof ModelCallFailure classified) return classified.httpStatus;
        }
        return null;
    }

    /** 按状态码归类 HTTP 失败。 */
    public static Category categoryOfStatus(int status) {
        if (status == 401 || status == 403) return Category.HTTP_AUTH;
        if (status == 404) return Category.HTTP_NOT_FOUND;
        if (status == 429) return Category.HTTP_RATE_LIMIT;
        if (status >= 400 && status < 500) return Category.HTTP_4XX;
        if (status >= 500 && status < 600) return Category.HTTP_5XX;
        return Category.HTTP_OTHER;
    }
}
