package com.kaiwu.common;

import jakarta.servlet.http.HttpServletRequest;

/** 不含业务语义的请求审计元数据。 */
public record RequestMetadata(String clientIp, String traceId) {

    /**
     * 从请求中提取审计所需的客户端 IP 与链路 ID。
     *
     * <p>优先取 {@code X-Forwarded-For} 的第一段——服务在 Gateway 之后，
     * {@code getRemoteAddr()} 拿到的是网关地址而不是真实来源。</p>
     */
    public static RequestMetadata from(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        String clientIp =
                forwarded == null || forwarded.isBlank() ? request.getRemoteAddr() : forwarded.split(",", 2)[0].trim();
        return new RequestMetadata(clientIp, request.getHeader("X-Trace-Id"));
    }
}
