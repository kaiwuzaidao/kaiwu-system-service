package com.kaiwu.module.agent.vo;

import java.time.Instant;
import java.util.Map;

/** 业务写任务的浏览器卡片数据；确认 token 只在首次预览返回。 */
public record AgentRemoteActionView(
        String actionId,
        String projectId,
        String projectCode,
        String capabilityCode,
        String capabilityName,
        String version,
        String status,
        String confirmationMode,
        Map<String, String> displayFields,
        Map<String, String> displayLabels,
        int affectedCount,
        Instant expiresAt,
        String confirmationToken,
        String confirmationPhrase,
        String reasonCode,
        Map<String, Object> result) {
    @Override
    public String toString() {
        return "AgentRemoteActionView[actionId=" + actionId + ", status=" + status + "]";
    }
}
