package com.kaiwu.module.agent.service;

import com.kaiwu.module.agent.dto.AgentRemoteWriteAuthorizationRequest;
import com.kaiwu.module.project.vo.ProjectAccessView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.Map;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AgentRemoteActionService {

    Pending prepare(
            String code,
            String version,
            String manifestHash,
            String paramsJson,
            String preconditionsJson,
            String previewJson,
            String correlationId,
            KaiwuContext actor);

    Claimed confirm(String actionId, String token, String typedPhrase, KaiwuContext actor);

    State cancel(String actionId, KaiwuContext actor);

    State status(String actionId, KaiwuContext actor);

    Claimed queryBinding(String actionId, KaiwuContext actor);

    State acceptResult(Claimed claimed, byte[] response, KaiwuContext actor);

    State markUnknown(Claimed claimed, KaiwuContext actor);

    Delegation authorizeDelegation(AgentRemoteWriteAuthorizationRequest request, String userId);

    public record PreviewView(Map<String, String> displayFields, Map<String, String> displayLabels, int affectedCount) {
        public PreviewView(Map<String, String> displayFields, int affectedCount) {
            this(displayFields, Map.of(), affectedCount);
        }
    }

    public record Pending(
            String actionId,
            String confirmationToken,
            String confirmationPhrase,
            PreviewView preview,
            Instant expiresAt) {
        @Override
        public String toString() {
            return "Pending[redacted]";
        }
    }

    public record State(
            String actionId,
            String projectId,
            String projectCode,
            String capabilityCode,
            String capabilityName,
            String version,
            String status,
            String confirmationMode,
            PreviewView preview,
            Instant expiresAt,
            String reasonCode,
            Map<String, Object> result) {}

    public record Delegation(String userId, ProjectAccessView access, int timeoutMs) {}

    public record Claimed(
            String actionId,
            String projectId,
            String projectCode,
            String capabilityCode,
            String version,
            String manifestHash,
            String paramsJson,
            String preconditionsJson,
            String previewHash,
            long expiresAtMillis,
            String correlationId) {
        @Override
        public String toString() {
            return "Claimed[redacted]";
        }
    }
}
