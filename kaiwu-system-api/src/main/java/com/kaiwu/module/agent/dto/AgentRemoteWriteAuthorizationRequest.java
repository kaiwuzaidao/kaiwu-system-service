package com.kaiwu.module.agent.dto;

/** Gateway 写用途复核契约。身份由 sessionId 解析，摘要由 Gateway 从原始请求计算。 */
public record AgentRemoteWriteAuthorizationRequest(
        String sessionId,
        String operation,
        String code,
        String version,
        String manifestHash,
        String paramsHash,
        String preconditionsHash,
        String previewHash,
        String actionId,
        Long actionExpiresAt,
        String correlationId) {
    @Override
    public String toString() {
        return "AgentRemoteWriteAuthorizationRequest[redacted]";
    }
}
