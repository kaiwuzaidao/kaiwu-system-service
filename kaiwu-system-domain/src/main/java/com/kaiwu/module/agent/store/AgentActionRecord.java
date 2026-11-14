package com.kaiwu.module.agent.store;

import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.project.dto.ProjectCreateRequest;
import java.util.Map;

/** Redis 中冻结的确认计划；仅存凭证摘要，状态更新必须比较完整旧值。 */
public record AgentActionRecord(
        String actionId,
        String userId,
        String sessionId,
        String capabilityCode,
        String version,
        String planHash,
        String tokenHash,
        ProjectCreateRequest project,
        long expiresAt,
        long startedAt,
        String status,
        String projectId,
        String reason,
        String permission,
        Map<String, Object> parameters,
        Map<String, String> previewFields,
        String confirmationMode,
        String confirmationPhrase) {
    public AgentActionRecord {
        // Pending project actions created before this contract gained a permission field remain queryable.
        if (permission == null && CapabilityCatalog.PROJECT_CREATE.equals(capabilityCode))
            permission = "system:project:create";
        if (confirmationMode == null) confirmationMode = "REQUIRED";
    }

    public AgentActionRecord(
            String actionId,
            String userId,
            String sessionId,
            String capabilityCode,
            String version,
            String planHash,
            String tokenHash,
            ProjectCreateRequest project,
            long expiresAt,
            long startedAt,
            String status,
            String projectId,
            String reason) {
        this(
                actionId,
                userId,
                sessionId,
                capabilityCode,
                version,
                planHash,
                tokenHash,
                project,
                expiresAt,
                startedAt,
                status,
                projectId,
                reason,
                "system:project:create",
                null,
                null,
                "REQUIRED",
                null);
    }

    public AgentActionRecord state(String next, long started, String resultId, String failure) {
        return new AgentActionRecord(
                actionId,
                userId,
                sessionId,
                capabilityCode,
                version,
                planHash,
                tokenHash,
                project,
                expiresAt,
                started,
                next,
                resultId,
                failure,
                permission,
                parameters,
                previewFields,
                confirmationMode,
                confirmationPhrase);
    }

    @Override
    public String toString() {
        return "AgentActionRecord[actionId=" + actionId + ", status=" + status + "]";
    }
}
