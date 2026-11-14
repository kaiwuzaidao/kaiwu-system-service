package com.kaiwu.module.agent.vo;

import com.kaiwu.module.project.dto.ProjectCreateRequest;
import java.time.Instant;
import java.util.Map;

/** 浏览器专用预览/结果，不进入模型；confirmationToken 只在首次预览响应存在。 */
public record AgentActionView(
        String actionId,
        String capabilityCode,
        String version,
        String status,
        ProjectCreateRequest project,
        Instant expiresAt,
        String confirmationToken,
        String projectId,
        String reason,
        String permission,
        Map<String, String> previewFields,
        String oneTimeSecret,
        String confirmationMode,
        String confirmationPhrase) {
    public AgentActionView(
            String actionId,
            String capabilityCode,
            String version,
            String status,
            ProjectCreateRequest project,
            Instant expiresAt,
            String confirmationToken,
            String projectId,
            String reason) {
        this(
                actionId,
                capabilityCode,
                version,
                status,
                project,
                expiresAt,
                confirmationToken,
                projectId,
                reason,
                "system:project:create",
                null,
                null,
                "REQUIRED",
                null);
    }

    @Override
    public String toString() {
        return "AgentActionView[actionId=" + actionId + ", status=" + status + "]";
    }
}
